defprotocol Operator do
  @protocoldoc """
  Defines the protocol for an operator.
  """
end

defmodule LocalOperator do
  use GenServer

  @behaviour Operator

  def init(init_arg) do
    {:ok, init_arg}
  end
end

defmodule DistributedOperator do
  use GenServer

  def init(init_arg) do
    {:ok, init_arg}
  end
end
