defmodule DuplicateNameError do
  @moduledoc """
  Every participant on a network must have a unique name
  associated with their pid.
  """

  defexception [:name, :pid]

  def message(%{name: name, pid: pid}) do
    "name #{name} alredy registered to process with pid #{pid}"
  end
end

defmodule NoSuchParticipantError do
  @moduledoc """
  Tried to contact a name that has not been registered
  on the network.
  """

  defexception [:name]

  def message(%{name: name}) do
    "tried to contact '#{name}' but no such name exists"
  end
end

defmodule Network do
  @moduledoc """
  ...
  """

  use Agent

  @doc """
  Called when a process wants to join the network.
  They must provide a unique name and their pid.
  """
  def join(network, name, pid) do
    # Agent.update(...)
    # ...

    :ok
  end

  @doc """
  Calls when a process wants to leave the network.
  """
  def leave(network, name) do
    # Agent.update(...)
    # ...

    :ok
  end

  @doc """
  Resolves the name of a connected process to its pid.
  """
  def resolve_name(name) do
    # Agent.get(...)
    # ...
    nil
  end

  @doc """
  Return the current list of participant names.
  """
  def participants(network) do
    # Agent.get(...)
    # ...
    []
  end
end

defmodule PeerToPeer do
  @moduledoc """
  ...
  """

  import Network

  @doc """
  ...
  """
  def send_message(recipient, message) do
    # resolve name -> pid
    # then send the message
    pid = resolve_name(recipient)
    send(pid, message)
    :ok
  end
end

defmodule BasicBroadcast do
  @moduledoc """
  ...
  """

  import PeerToPeer

  @doc """
  ...
  """
  def broadcast(network, message) do
    for participant <- participants(network) do
      send_message(participant, message)
    end
  end
end
