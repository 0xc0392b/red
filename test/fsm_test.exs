# example state A
defmodule FSMTest.State.A do
  use State,
    id: :a,
    to: [:a, :b],
    substates: []

  transition do
    cond do
      input > 10 -> :error
      rem(input, 2) == 0 -> {:ok, :a}
      rem(input, 2) != 0 -> {:ok, :b}
    end
  end

  output do
    input
  end
end

# example state B
defmodule FSMTest.State.B do
  use State,
    id: :b,
    to: [:b, :c],
    substates: []

  transition do
    cond do
      input > 20 -> :error
      rem(input, 2) == 0 -> {:ok, :b}
      rem(input, 2) != 0 -> {:ok, :c}
    end
  end

  output do
    input
  end
end

# example state C
defmodule FSMTest.State.C do
  use State,
    id: :c,
    to: [:c, :a],
    substates: []

  transition do
    cond do
      input < 10 -> :error
      input > 30 -> :error
      rem(input, 2) == 0 -> {:ok, :c}
      rem(input, 2) != 0 -> {:ok, :a}
    end
  end

  output do
    input
  end
end

# example machine
defmodule FSMTest.Machine do
  use Machine,
    name: :test_machine,
    states: [
      FSMTest.State.A,
      FSMTest.State.B,
      FSMTest.State.C
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

  routine "random numbers" do
    # ...
  end
end

# test FSM with the above states
defmodule FSMTest.MachineTest do
  use ExUnit.Case
  doctest Machine

  test "creating a test machine" do
    # do work here
    # ...

    assert true
  end
end
