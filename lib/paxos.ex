defmodule Paxos.Accepted do
  @moduledoc """
  A struct that represents a pair (accepted value, ballot it was
  accepted in).
  """

  # contains any value and a Paxos.Ballot struct.
  # require all keys.
  @enforce_keys [:value, :ballot]
  defstruct [:value, :ballot]

  # Implements the String.Chars protocol so it is printable.
  defimpl String.Chars do
    def to_string(accepted) do
      "(#{accepted.number}, #{accepted.ballot})"
    end
  end
end

defmodule Paxos.Ballot do
  @moduledoc """
  A struct that represents a ballot in a Paxos network. A ballot "belongs"
  to a leader and has a unique, locally monotonically increasing
  "ballot number".
  """

  # contains a number and a leader PID.
  # require all keys.
  @enforce_keys [:number, :pid]
  defstruct [:number, :pid]

  @doc """
  Compares two ballots. A ballot is a pair (ballot number, leader PID).
  A ballot b1 is greater than another ballot b2 if:
  - b1.number > b2.number
    or
  - b1.number == b2.number and b1.pid > b2.pid
  """
  def higher_or_equal?(ballot_1, ballot_2) do
    cond do
      ballot_1.number > ballot_2.number ->
        true

      ballot_1.number == ballot_2.number and
          ballot_1.pid > ballot_2.pid ->
        true

      ballot_1.number == ballot_2.number and
          ballot_1.pid == ballot_2.pid ->
        true

      true ->
        false
    end
  end

  @doc """
  Provides the "locally monotonically increasing" functionality. Simply
  creates and returns a new ballot with the given PID and ballot
  number + 1.
  > If the last ballot known to p is (n, q), then p chooses (n+1, p).
  """
  def increase(ballot, pid) do
    %Paxos.Ballot{:number => ballot.number + 1, :pid => pid}
  end

  # Implements the String.Chars protocol so it is printable.
  defimpl String.Chars do
    def to_string(ballot) do
      "(#{ballot.number}, #{inspect(ballot.pid)})"
    end
  end
end

defmodule Paxos.Processor do
  @moduledoc """
  GenServer. Performs all roles in the original description of the
  Paxos algorithm: client, learner, leader, proposer, and acceptor.
  All messages are prefixed with their recipient's role. This allows
  a Paxos.Processor to distinguish and forward them to the correct
  destination processes.
  ### Client
  The "client" interacts with the Paxos network. In this system, the
  client is provided in the form of two functions: propose and
  start_ballot. These are essentially the "API" of the Paxos subsystem,
  which is used by processes higher-up in the supervision tree.
  ### Learner
  The "learner" is informed when an agreement is made and a value is
  decided. In this system, the learner is the parent process "upper"
  who will receive the message {:decide, value} whenever a value
  is decided.
  ### Proposer
  A "proposer" receives values from the client and proposes them to
  the current leader (who is also a proposer). The leader handles
  most of the Paxos algorithm. In this system there are no proposers.
  The description for "Leader" explains this design choice.
  ### Leader
  A "leader" is simply a distinguished proposer. They create a new
  ballot and broadcast it to the acceptors, trying to achieve a
  quorum: more than half of the acceptors respond with a promise.
  In this system, all proposers have the capacity to be a leader at
  any point in time. From an architectural perspective, this means
  proposers and leaders are the exact same thing. This is why a
  Paxos.Processor has no "proposer" and only a "leader" child process,
  which is a GenServer similar to Paxos.Role.Acceptor.
  ### Acceptor
  The "acceptors" act as the distributed fault-tolerant memory of the
  Paxos network. In this system, acceptors run as child processes to
  a Paxos.Processor. They are implemented as GenServers: they expose an
  API and maintain their own local state. They send messages using a
  Paxos.Network and receive messages from a Paxos.Processor.
  """

  use GenServer

  @doc """
  Start the GenServer. Takes a processor name, the list of participants
  in the network, and the PID of the parent process. Registers the name
  of the processor with the GenServer's PID in the global registry.
  Ideally this would be a start_link so that the Paxos subsystem would
  fit correctly into an OTP supervision tree. However, the assignment
  tests expect a start/3 function that returns a PID and not {:ok, pid}.
  Also, linking a Paxos.Processor to the parent process breaks the
  tests when they begin simulating node "crashes".
  """
  def start(name, participants, upper) do
    {:ok, pid} =
      GenServer.start(
        __MODULE__,
        name: name,
        participants: participants,
        upper: upper
      )

    :yes = :global.register_name(name, pid)

    pid
  end

  @doc """
  GenServer initialisation callback. Spawns acceptor and leader child
  processes and stores their PIDs in the initial state.
  """
  @impl true
  def init(init_arg) do
    roles =
      [learner: init_arg[:upper]] ++
        for {role_name, module} <- [
              {:acceptor, Paxos.Role.Acceptor},
              {:leader, Paxos.Role.Leader}
            ] do
          {:ok, pid} = module.start_link(init_arg)
          {role_name, pid}
        end

    {:ok, roles}
  end

  @doc """
  GenServer receive message callback. Handles all messages sent to a
  Paxos.Processor. All messages must be prefixed with one of the
  following atoms:
  1. :to_acceptors
  2. :to_learners
  3. :to_leader
  The message (excluding the above destination prefix) is then
  forwarded to the correct destination.
  """
  @impl true
  def handle_info({role, msg}, roles) do
    case role do
      :to_acceptors -> send(roles[:acceptor], msg)
      :to_learners -> send(roles[:learner], msg)
      :to_leader -> send(roles[:leader], msg)
    end

    {:noreply, roles}
  end

  @doc """
  GenServer asynchronous API call.
  """
  # Handles messages for :propose.
  @impl true
  def handle_cast({:propose, value}, roles) do
    :ok = Paxos.Role.Leader.set_value(roles[:leader], value)
    {:noreply, roles}
  end

  # Handles messages for :start_ballot.
  @impl true
  def handle_cast({:start_ballot}, roles) do
    :ok = Paxos.Role.Leader.send_prepare(roles[:leader])
    {:noreply, roles}
  end

  @doc """
  Asynchronous API call. Sets the processor'2 "current value". This is
  the value that's proposed by when start_ballot is called. Always
  returns :ok.
  """
  def propose(processor, value) do
    :ok = GenServer.cast(processor, {:propose, value})
    :ok
  end

  @doc """
  Asynchronous API call. Start a new Paxos instance and propose the
  current value. Re-syncs the global name registry beforehand. Always
  returns :ok.
  """
  def start_ballot(processor) do
    :ok = :global.sync()
    :ok = GenServer.cast(processor, {:start_ballot})
    :ok
  end
end

defmodule Paxos.Role.Acceptor do
  @moduledoc """
  GenServer. Performs the role of a Paxos "acceptor". Receives and
  responds to messages from a leader in this Paxos network.
  An Acceptor's initial state consists of:
  - a ballot with the number zero;
  - a "null" previously accepted value;
  - the PID of a "network connection" that facilitates sending
    and broadcasting messages.
  Acceptors receive these messages:
  - {:prepare, ballot, leader}
  - {:propose, ballot, value, leader}
  And send these messages:
  - {:to_leader, {:promise, ballot, state[:last_accepted]}}
  - {:to_leader, {:accept, ballot, value}}
  """

  use GenServer

  @doc """
  Starts the GenServer process and links it to the parent.
  init_arg is expected to be a keyword list containing the values passed
  to Paxos.Processor.start().
  """
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg)
  end

  @doc """
  GenServer initialisation callback. Creates a new "network connection"
  and constructs the initial state. Always returns {:ok, initial_state}.
  """
  @impl true
  def init(init_arg) do
    {:ok, network} = Paxos.Network.start_link(init_arg)

    initial_ballot = %Paxos.Ballot{number: 0, pid: self()}
    nothing_yet = %Paxos.Accepted{:value => nil, :ballot => initial_ballot}

    initial_state = %{
      :network => network,
      :latest_known_ballot => initial_ballot,
      :last_accepted => nothing_yet
    }

    {:ok, initial_state}
  end

  @doc """
  GenServer receive message callback.
  """
  # Handles Paxos :prepare messages. Responds to the leader if the
  # provided ballot number is >= the last known ballot, otherwise
  # ignores the message.
  @impl true
  def handle_info({:prepare, ballot, leader}, state) do
    if Paxos.Ballot.higher_or_equal?(
         ballot,
         state[:latest_known_ballot]
       ) do
      new_state = Map.put(state, :latest_known_ballot, ballot)

      # send {:to_leader, {:promise, ballot, last_accepted}}
      # back to leader
      :ok =
        Paxos.Network.send_to(
          state[:network],
          leader,
          {:to_leader, {:promise, ballot, state[:last_accepted]}}
        )

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  # Handles Paxos :propose messages. Responds to the leader if the provided
  # ballot number is >= the last known ballot, otherwise ignores the message.
  @impl true
  def handle_info({:propose, ballot, value, leader}, state) do
    if Paxos.Ballot.higher_or_equal?(
         ballot,
         state[:latest_known_ballot]
       ) do
      last_accepted = %Paxos.Accepted{:value => value, :ballot => ballot}
      new_state = Map.put(state, :last_accepted, last_accepted)

      # send {:to_leader, {:accept, ballot, value}}
      # back to leader
      :ok =
        Paxos.Network.send_to(
          state[:network],
          leader,
          {:to_leader, {:accept, ballot, value}}
        )

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
end

defmodule Paxos.Role.Leader do
  @moduledoc """
  GenServer. Performs the role of a Paxos "leader" - a distinguished
  proposer. Receives and responds to messages from multiple Acceptors
  in this Paxos network.
  A Leader's initial state consists of:
  - a nil current value (which is updated by set_value);
  - no received promise or accept messages;
  - the PID of a "network connection" that facilitates sending
    and broadcasting messages;
  - the name of the processor and total number of participants;
  - a last known ballot with the number zero.
  Leader receive these messages:
  - {:promise, ballot, last_accepted}
  - {:accept, ballot, value}
  Send these messages:
  - {:to_learners, {:decide, value}}
  - {:to_acceptors, {:prepare, ballot, :name}}
  - {:to_acceptors, {:propose, ballot, value, :name}}
  And have the following asynchronous API:
  - send_prepare(leader)
  - set_value(leader, value)
  """

  use GenServer

  @doc """
  Starts the GenServer process and links it to the parent.
  init_arg is expected to be a keyword list containing the values passed
  to Paxos.Processor.start().
  """
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg)
  end

  @doc """
  GenServer initialisation callback. Creates a new "network connection"
  and constructs the initial state. Always returns {:ok, initial_state}.
  """
  @impl true
  def init(init_arg) do
    {:ok, network} = Paxos.Network.start_link(init_arg)

    initial_state = %{
      :current_value => nil,
      :promises_received => [],
      :accepts_received => [],
      :network => network,
      :name => init_arg[:name],
      :total_participants => length(init_arg[:participants]),
      :latest_known_ballot => %Paxos.Ballot{number: 0, pid: self()}
    }

    {:ok, initial_state}
  end

  @doc """
  GenServer receive message callback.
  """
  # Handles Paxos :promise messages. Responds to all Acceptors
  # once the number of promise messages received represents a quorum.
  @impl true
  def handle_info({:promise, ballot, last_accepted}, state) do
    # append the :promise message to the current list of :promise
    # messages.
    promises_received = state[:promises_received] ++ [last_accepted]

    if quorum?(state[:total_participants], promises_received) do
      # we can propose our initial value if all Acceptors in the
      # quorum have no previously accepted value.
      # otherwise, propose the value with the highest ballot
      # number.
      value =
        case highest_ballot(promises_received) do
          nil -> state[:current_value]
          highest -> highest.value
        end

      # send {:to_acceptors, {:propose, ballot, value, :name}}
      # to all acceptors
      :ok =
        Paxos.Network.broadcast(
          state[:network],
          {:to_acceptors, {:propose, ballot, value, state[:name]}}
        )

      # reset the list of current promises received
      new_state = Map.put(state, :promises_received, [])
      {:noreply, new_state}
    else
      # use the updated promises list
      new_state = Map.put(state, :promises_received, promises_received)
      {:noreply, new_state}
    end
  end

  # Handles Paxos :accept messages. Sends a :decide message to all Paxos
  # "learners" once the number of :accept messages received represents a
  # quorum.
  # Recall: in this system, a learner is the "upper" process associated
  # with the PID provided to the Paxos.Processor.start() function. A
  # {:decide, value} message will be send to that process once a decision
  # has been made by this leader.
  @impl true
  def handle_info({:accept, _, value}, state) do
    # append the :accept message to the current list of :accept
    # messages.
    accepts_received = state[:accepts_received] ++ [value]

    if quorum?(state[:total_participants], accepts_received) do
      # send {:to_learners, {:decide, value}}
      # to all learners
      :ok =
        Paxos.Network.broadcast(
          state[:network],
          {:to_learners, {:decide, value}}
        )

      # reset the list of current accepts received
      new_state = Map.put(state, :accepts_received, [])
      {:noreply, new_state}
    else
      # use the updated accepts list
      new_state = Map.put(state, :accepts_received, accepts_received)
      {:noreply, new_state}
    end
  end

  @doc """
  GenServer asynchronous API call.
  """
  # Handles messages for :set_value.
  @impl true
  def handle_cast({:set_value, value}, state) do
    # update the current value and reset the list of promises
    # and accepts received in the past.
    new_state =
      Map.put(state, :current_value, value)
      |> Map.put(:promises_received, [])
      |> Map.put(:accepts_received, [])

    {:noreply, new_state}
  end

  # Handles messages for :send_prepare, which begins a new Paxos instance.
  @impl true
  def handle_cast({:send_prepare}, state) do
    ballot = Paxos.Ballot.increase(state[:latest_known_ballot], self())
    new_state = Map.put(state, :latest_known_ballot, ballot)

    # send {:to_acceptors, {:prepare, ballot, :name}}
    # to all acceptors
    :ok =
      Paxos.Network.broadcast(
        state[:network],
        {:to_acceptors, {:prepare, ballot, state[:name]}}
      )

    {:noreply, new_state}
  end

  @doc """
  Asynchronous API call. Sets the value the Leader will propose in the
  next Paxos instance. Always returns :ok.
  """
  def set_value(leader, value) do
    :ok = GenServer.cast(leader, {:set_value, value})
    :ok
  end

  @doc """
  Asynchronous API call. Starts a new instance of Paxos using the Leader
  process "leader" as the distinguished proposer. Always returns :ok.
  """
  def send_prepare(leader) do
    :ok = GenServer.cast(leader, {:send_prepare})
    :ok
  end

  # Returns true when the number of messages in messages_received is
  # greater than half the number acceptors in the network.
  # quorum = > 50%.
  defp quorum?(num_acceptors, messages_received) do
    minimum = num_acceptors / 2
    received = length(messages_received)
    received > minimum
  end

  # If all promises contain nil values then return nil - telling the
  # leader it can just propose its original value. Otherwise, return
  # the value with the highest ballot.
  defp highest_ballot(promises_received) do
    all_nil? =
      Enum.all?(
        Enum.map(
          promises_received,
          fn promise -> promise.value == nil end
        )
      )

    unless all_nil? do
      Enum.max_by(
        promises_received,
        fn promise -> promise.ballot.number end
      )
    else
      nil
    end
  end
end
