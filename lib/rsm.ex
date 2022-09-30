defmodule StorageBackend do
  @moduledoc """
  Defines a
  """

  # start and link to parent process
  @callback start_link(any()) :: {:ok, pid()}

  # write to the store
  @callback write(pid(), any()) :: :ok | :error

  # fetch the latest record
  @callback latest(pid()) :: {:ok, any()} | :error

  # read all records
  @callback all(pid(), any()) :: [any()] | :empty
end

defmodule StorageBackend.InMemory do
  @moduledoc """
  ...
  """

  use Agent

  @behaviour StorageBackend

  @impl true
  def start_link(initial) do
    Agent.start_link(fn -> initial end)
  end

  @impl true
  def write(store, input) do
    :ok =
      Agent.update(
        store,
        fn state -> state ++ [input] end
      )

    :ok
  end

  @impl true
  def latest(store) do
    last_entry =
      Agent.get(
        store,
        fn state -> state |> Enum.take(-1) end
      )

    case last_entry do
      [entry] -> entry
      [] -> :empty
    end
  end

  @impl true
  def all(store, starting_from) do
    # TODO
    # filter using starting_from

    all_entries =
      Agent.get(
        store,
        fn state -> state end
      )
      |> Enum.filter(fn x -> true end)

    case all_entries do
      [] -> :empty
      entries -> entries
    end
  end
end

defmodule StorageBackend.FlatFile do
  @moduledoc """
  ...
  """

  use Agent

  @behaviour StorageBackend

  @impl true
  def start_link(file_path) do
    Agent.start_link(fn -> nil end)
  end

  @impl true
  def write(store, input) do
    # TODO
    # append to file
    :error
  end

  @impl true
  def latest(store) do
    # TODO
    # get last item in file
    :empty
  end

  @impl true
  def all(store, starting_from) do
    # TODO
    # turn file into stream
    :empty
  end
end

defmodule DistributedLog do
  @moduledoc """
  ...
  """

  use GenServer

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg)
  end

  def init(
        storage_backend: storage_backend,
        storage_options: storage_opts,
        participants: participants
      ) do
    {:ok, store_pid} = storage_backend.start_link(storage_opts)
    {:ok, consensus_pid} = ConsensusModule.start_link(participants)

    {
      :ok,
      %{
        :store => store_pid,
        :consensus => consensus_pid,
        :backend => storage_backend
      }
    }
  end

  def handle_call({:append, input}, _, state) do
    # do work here
    # ...

    {:reply, nil, state}
  end

  def handle_call(:latest, _, state) do
    case state[:backend].latest(state[:store]) do
      :empty -> {:reply, :empty, state}
      :error -> {:reply, :error, state}
      latest -> {:reply, latest, state}
    end
  end

  def handle_call({:replay, starting_from}, _, state) do
    case state[:backend].all(state[:store], starting_from) do
      :empty -> {:reply, :empty, state}
      :error -> {:reply, :error, state}
      entries -> {:reply, entries, state}
    end
  end

  @doc """
  ...
  """
  def append(log, input) do
    GenServer.call(log, {:append, input})
  end

  @doc """
  ...
  """
  def latest(log) do
    GenServer.call(log, :latest)
  end

  @doc """
  ...
  """
  def replay(log, starting_from) do
    GenServer.call(log, {:replay, starting_from})
  end
end

defmodule ReplicatedStateMachine do
  @moduledoc """
  ...
  """

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    # TODO
    # create distributed log

    # TODO
    # integrate finite state machine

    {:ok, %{}}
  end

  @doc false
  defmacro __using__(_opts) do
    quote do
      # ...
    end
  end

  # do work here
  # ...
end
