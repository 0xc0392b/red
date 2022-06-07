defmodule Network do
  @moduledoc """
  ...
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      # do work here
      # ...
    end
  end
end

defmodule PeerToPeer do
  @moduledoc """
  ...
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use Network

      # implement network behaviour
      # on-top of simple network link
      # ...
    end
  end
end

defmodule BasicBroadcast do
  @moduledoc """
  ...
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      use PeerToPeer

      # implement network behaviour
      # on-top of peer-to-peer
      # ...
    end
  end
end
