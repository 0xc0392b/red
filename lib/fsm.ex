defmodule InvalidTransitionError do
  @moduledoc """
  Transition function tried to move to a state
  outside of its "to" list.
  """

  defexception [:from, :to, :allowed]

  def message(%{from: from, to: to, allowed: allowed}) do
    valid_transitions =
      allowed
      |> Enum.map(fn x -> "(#{from} -> #{x})" end)
      |> Enum.join(", ")

    "invalid transition (#{from} -> #{to}), " <>
      "allowed: #{valid_transitions}"
  end
end

defmodule BrokenRoutineError do
  @moduledoc """
  ...
  """

  defexception [:next_step, :next_state, :remaining]

  def message(%{
        next_step: next_step,
        next_state: next_state,
        remaining: remaining
      }) do
    remaining_steps =
      remaining
      |> Enum.map(fn x -> "'#{x}'" end)
      |> Enum.join(", ")

    "next step is #{next_step} but got #{next_state}, " <>
      "remaining steps are: #{remaining_steps}"
  end
end

defmodule NoSuchStateError do
  @moduledoc """
  Tried to access a state id that does not exist.
  """

  defexception [:state_id]

  def message(%{state_id: state_id}) do
    "state '#{state_id}' does not exist"
  end
end

defmodule NoSuchRoutineError do
  @moduledoc """
  Tried to execute a routine that does not exist.
  """

  defexception [:name]

  def message(%{name: name}) do
    "routine #{name} does not exist"
  end
end

defmodule State do
  @moduledoc """
  Template for a state.
  """

  # state transition function
  @callback transition(any(), any()) :: {:ok, atom()} | :error

  # transition output function
  @callback output(any(), any()) :: any()

  @doc false
  defmacro __using__(id: id, to: to, substates: substates) do
    quote bind_quoted: [id: id, to: to, substates: substates] do
      @behaviour State

      @unique_state_id id
      @neighbours to
      @substates substates

      def id, do: @unique_state_id
      def to, do: @neighbours
    end
  end
end

defmodule Machine do
  @moduledoc """
  Template for a finite state machine.
  """

  @doc false
  defmacro __using__(name: name, states: states) do
    quote bind_quoted: [name: name, states: states] do
      import Machine

      use Agent

      @machine_name name
      @states states

      def start_link(ctx) do
        Agent.start_link(fn -> ctx end)
      end

      # return the machine's name
      def name, do: @machine_name

      @doc """
      Send a single event to the machine.
      """
      def event(machine, state_id, input) do
        # get the machine's context
        ctx = Agent.get(machine, fn ctx -> ctx end)

        # pick the state, making sure it exists
        state =
          case @states[state_id] do
            nil -> raise NoSuchStateError, state_id: state_id
            state -> state
          end

        # transition on given input
        outcome =
          case state.transition(input, ctx) do
            # successful transition if the next state is
            # allowed otherwise raise TransitionError
            {:ok, next_state} ->
              if next_state not in state.to do
                raise InvalidTransitionError,
                  from: state.id,
                  to: next_state,
                  allowed: state.to
              else
                {:ok, {next_state, state.output(input, ctx)}}
              end

            # the transition function returned an error on
            # the given input
            :error ->
              {:error, {state.id, input}}
          end

        # the outcome of the event
        outcome
      end

      @doc """
      Chain multiple events together, starting with an
      initial input.
      """
      def events(machine, input, [step | remaining]) do
        # the chain function actually triggers the event
        # and continues the chain until halt
        chain_fn = fn ->
          case event(machine, step, input) do
            # successful transition on input
            {:ok, {next_state, output}} ->
              if Enum.any?(remaining) do
                # continue the chain if there's steps remaining
                [next_step | _] = remaining

                # make sure the next state is the same as the
                # routine's next step
                if next_step != next_state do
                  raise BrokenRoutineError,
                    next_step: next_step,
                    next_state: next_state,
                    remaining: remaining
                else
                  {:next, events(machine, output, remaining)}
                end
              else
                # halt when finished routine
                {:halt, {:done, output}}
              end

            # halt chain if error on input
            :error ->
              {:halt, :error}
          end
        end

        # return the current step, input, and chain function
        {chain_fn, {step, input}}
      end

      @doc """
      Call a pre-defined routine on a given input.
      """
      def routine(machine, name, input) do
        # the routine's full name
        routine_name = :"routine_#{name}"

        # pick the routine, making sure it exists
        routine =
          if not function_exported?(__MODULE__, routine_name, 0) do
            raise NoSuchRoutineError, name: routine_name
          else
            apply(__MODULE__, routine_name, [])
          end

        # begin the routine's chain of state transitions
        events(machine, input, routine)
      end
    end
  end

  @doc """
  Defines a sequence of steps as a routine. Appends it
  to the module's list of routines.
  """
  defmacro routine(name, steps: steps) do
    # the routine's full name
    routine_name = :"routine_#{name}"

    quote do
      def unquote(routine_name)(), do: unquote(steps)
    end
  end
end

defmodule Operator do
  @moduledoc """
  Template for an operator. Must be provided a finite state
  machine and a starting state.
  """

  @doc false
  defmacro __using__(fsm: fsm, start_state: start_state) do
    quote bind_quoted: [fsm: fsm, start_state: start_state] do
      use Agent

      @fsm fsm
      @start_state start_state

      def start_link(ctx) do
        # start the machine
        {:ok, pid} = @fsm.start_link(ctx)

        # set the agent's state to (fsm pid, start state)
        Agent.start_link(fn ->
          %{
            fsm_pid: pid,
            current_state: @start_state
          }
        end)
      end

      defp set_state(operator, next_state) do
        Agent.update(
          operator,
          fn ctx -> %{ctx | current_state: next_state} end
        )
      end

      @doc """
      Return the operator's current state.
      """
      def current_state(operator) do
        Agent.get(operator, fn ctx -> ctx[:current_state] end)
      end

      @doc """
      Send an event to the machine and update the
      operator's current state accordingly.
      """
      def input(operator, input) do
        # get the machine's pid
        machine = Agent.get(operator, fn ctx -> ctx[:fsm_pid] end)

        # the machine's current state
        state = current_state(operator)

        # execute the event
        case @fsm.event(machine, state, input) do
          # successful transition: store the machine's new state
          {:ok, {next_state, output_value}} ->
            :ok = set_state(operator, next_state)
            {:ok, {next_state, output_value}}

          # error on input
          {:error, output} ->
            {:error, output}
        end
      end
    end
  end
end
