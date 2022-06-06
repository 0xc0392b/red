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
  def output(input, _), do: input
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
  def output(input, _), do: input
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
      input < 10 -> :error
      input > 30 -> :error
      rem(input, 2) == 0 -> {:ok, :c}
      rem(input, 2) != 0 -> {:ok, :a}
    end
  end

  @impl true
  def output(input, _), do: input
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

  routine "12345" do
    # ...
  end

  routine "123a" do
    # ...
  end

  routine "even numbers" do
    # ...
  end

  routine "odd numbers" do
    # ...
  end
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
            [in: {:a, 1}, out: {:b, 1}],
            [in: {:a, 2}, out: {:a, 2}],
            [in: {:b, 1}, out: {:b, 1}],
            [in: {:b, 2}, out: {:c, 2}],
            [in: {:c, 12}, out: {:c, 12}],
            [in: {:c, 15}, out: {:a, 15}]
          ] do
        {input_state, input_value} = input
        {expect_state, expect_value} = expect_output

        {:ok, {next_state, output}} =
          FSMTest.Machine.event(
            pid,
            input_state,
            input_value
          )

        next_state == expect_state and
          output == expect_value
      end

    assert Enum.all?(outcomes)
  end

  test "testing pre-defined routines" do
    # do work here
    # ...

    true
  end
end
