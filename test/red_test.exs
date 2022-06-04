defmodule RedTest do
  use ExUnit.Case
  doctest Red

  test "greets the world" do
    assert Red.hello() == :world
  end
end
