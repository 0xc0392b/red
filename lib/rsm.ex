defmodule TransactionLog do
  @moduledoc """
  ...
  """

  # operator should log the outcome of each
  # state transition to some storage backend
  # ...
end

defmodule ReplicatedStateMachine do
  @moduledoc """
  Template for a replicated state machine.
  This module essentially brings everything together.
  Users are expected to provide a unique name for each
  participant replicating the machine in the cluster, as
  well as a finite state machine and starting state.
  """

  @doc false
  defmacro __using__(
             name: name,
             fsm: fsm,
             start_state: start_state
           ) do
    quote do
      use Operator,
        fsm: fsm,
        start_state: start_state

      import Paxos
      import Network
      import BasicBroadcast
      import TransactionLog

      @name name
      @participants participants

      # operator
      # ...

      # broadcast network
      # ...

      # paxos
      # ...

      # transaction log
      # ...

      # finite state machine
      # ...
    end
  end
end
