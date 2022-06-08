# example state A
defmodule FSMTest.State.A do
  use State,
    id: :a,
    to: [:a, :b],
    substates: []

  @impl true
  def transition(input, _) do
    cond do
      input > 10 -> :error
      rem(input, 2) == 0 -> {:ok, :a}
      rem(input, 2) != 0 -> {:ok, :b}
    end
  end

  @impl true
  def output(input, _), do: input + 1
end

# example state B
defmodule FSMTest.State.B do
  use State,
    id: :b,
    to: [:b, :c],
    substates: []

  @impl true
  def transition(input, _) do
    cond do
      input > 20 -> :error
      rem(input, 2) != 0 -> {:ok, :b}
      rem(input, 2) == 0 -> {:ok, :c}
      input == 420 -> {:ok, :x}
    end
  end

  @impl true
  def output(input, _), do: input + 2
end

# example state C
defmodule FSMTest.State.C do
  use State,
    id: :c,
    to: [:c, :a],
    substates: []

  @impl true
  def transition(input, _) do
    cond do
      input > 30 -> :error
      rem(input, 2) == 0 -> {:ok, :c}
      rem(input, 2) != 0 -> {:ok, :a}
    end
  end

  @impl true
  def output(input, _), do: input + 3
end

# example machine
defmodule FSMTest.Machine do
  use Machine,
    name: :test_machine,
    states: [
      a: FSMTest.State.A,
      b: FSMTest.State.B,
      c: FSMTest.State.C
    ]

  routine(:testing_1,
    steps: [
      :a,
      :b,
      :c
    ]
  )

  routine(:testing_2,
    steps: [
      :a,
      :a,
      :b
    ]
  )
end

# example machine operator
defmodule FSMTest.Operator do
  use Operator,
    fsm: FSMTest.Machine,
    start_state: :a

  # put helper functions here
  # ...
end

# test FSM with the above states
defmodule FSMTest.MachineTest do
  use ExUnit.Case
  doctest Machine

  test "manually entering events in a test machine" do
    ctx = %{"some" => "context"}
    {:ok, pid} = FSMTest.Machine.start_link(ctx)

    outcomes =
      for [in: input, out: expect_output] <- [
            [in: {:a, 1}, out: {:b, 2}],
            [in: {:a, 2}, out: {:a, 3}],
            [in: {:b, 1}, out: {:b, 3}],
            [in: {:b, 2}, out: {:c, 4}],
            [in: {:c, 12}, out: {:c, 15}],
            [in: {:c, 15}, out: {:a, 18}]
          ] do
        {input_state, input_value} = input
        {expect_state, expect_value} = expect_output

        {:ok, {next_state, output_value}} =
          FSMTest.Machine.event(
            pid,
            input_state,
            input_value
          )

        next_state == expect_state and
          output_value == expect_value
      end

    assert Enum.all?(outcomes)
  end

  test "testing pre-defined routines" do
    ctx = %{"some" => "context"}

    outcomes =
      for {routine, initial_input, expected_outputs} <- [
            {:testing_1, 1, [{:a, 1}, {:b, 2}, {:c, 4}, 7]},
            {:testing_2, 2, [{:a, 2}, {:a, 3}, {:b, 4}, 6]}
          ] do
        {:ok, pid} = FSMTest.Machine.start_link(ctx)

        {chain_fn_1, output_1} =
          FSMTest.Machine.routine(
            pid,
            routine,
            initial_input
          )

        # do step 1
        {:next, {chain_fn_2, output_2}} = chain_fn_1.()

        # do step 2
        {:next, {chain_fn_3, output_3}} = chain_fn_2.()

        # do step 3
        {:halt, {:done, output_4}} = chain_fn_3.()

        output_1 == Enum.at(expected_outputs, 0) and
          output_2 == Enum.at(expected_outputs, 1) and
          output_3 == Enum.at(expected_outputs, 2) and
          output_4 == Enum.at(expected_outputs, 3)
      end

    assert Enum.all?(outcomes)
  end
end

# create an operator with the test machine
defmodule FSMTest.OperatorTest do
  use ExUnit.Case
  doctest Operator

  test "create example operator" do
    ctx = %{"some" => "context"}

    # create operator
    {:ok, pid} = FSMTest.Operator.start_link(ctx)

    # check current state
    current_state = FSMTest.Operator.current_state(pid)

    assert current_state == :a
  end

  test "operator's state is updated correctly" do
    ctx = %{"some" => "context"}

    # create operator
    {:ok, pid} = FSMTest.Operator.start_link(ctx)

    # input "1", check new state
    {:ok, {next_state, output_value}} =
      FSMTest.Operator.handle_input(
        pid,
        1
      )

    assert output_value == 2 and
             next_state == :b and
             FSMTest.Operator.current_state(pid) == :b
  end
end
