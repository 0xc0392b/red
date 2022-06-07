defmodule Operator do
  @moduledoc """
  ...
  """

  @doc false
  defmacro __using__(machine: machine) do
    quote bind_quoted: [machine: machine] do
      use GenServer

      @machine machine

      def start_link(ctx) do
        GenServer.start_link(__MODULE__, ctx)
      end

      def init(init_arg) do
        {:ok, init_arg}
      end
    end
  end
end

defmodule LocalOperator do
  @moduledoc """
  ...
  """

  use Operator, machine: nil
end

defmodule DistributedOperator do
  @moduledoc """
  ...
  """

  use Operator, machine: nil
end
