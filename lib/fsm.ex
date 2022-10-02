defmodule InvalidTransitionError do
  @moduledoc """
  Transition function tried to move to a state
  outside of its "to" list.
  """

  defexception [:allowed, :from, :to]

  def message(%{allowed: allowed, from: from, to: to}) do
    # concatenate valid transitions from given state
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
  Got an invalid "next state" when executing a routine.
  """

  defexception [:next_step, :next_state, :remaining]

  def message(%{
        next_step: next_step,
        next_state: next_state,
        remaining: remaining
      }) do
    # concatenate remaining steps in routine
    remaining_steps =
      remaining
      |> Enum.map(fn x -> "'#{x}'" end)
      |> Enum.join(", ")

    "routine's next step is #{next_step} but got #{next_state}, " <>
      "remaining steps are: #{remaining_steps}"
  end
end

defmodule NoSuchStateError do
  @moduledoc """
  Tried to access a state that does not exist.
  """

  defexception [:machine_name, :state_name]

  def message(%{
        machine_name: name,
        state_name: state
      }) do
    "machine #{name} has no such state '#{state}'"
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
  defmacro __using__(name: name, to: to, substates: substates) do
    quote bind_quoted: [name: name, to: to, substates: substates] do
      @behaviour State

      @state_name name
      @neighbours to
      @substates substates

      def name, do: @state_name
      def to, do: @neighbours
      def substates, do: @substates
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

      # true if can transition from origin_state to a state with name
      # next_state_name either directly or via a superstate
      # else false
      defp valid_transition?(origin_state, next_state_name) do
        if next_state_name in origin_state.to do
          true
        else
          # TODO: check super states
          # ...

          false
        end
      end

      # resolves a state name to its module via the @states map
      # raises NoSuchStateError if invalid name
      defp pick_state(state_name) do
        case @states[state_name] do
          # state_name does not exist in @states
          nil ->
            raise NoSuchStateError,
              machine_name: @machine_name,
              state_name: state_name

          # return the module for state_name
          state ->
            state
        end
      end

      # calls the transition function on the given input
      # then calls the output function if allowed to transition
      # to the next state
      defp do_transition(origin_state, input, ctx) do
        case origin_state.transition(input, ctx) do
          # successful transition
          {:ok, next_state_name} ->
            if not valid_transition?(origin_state, next_state_name) do
              # not allowed to transition to next_state_name
              raise InvalidTransitionError,
                allowed: origin_state.to,
                from: origin_state.name,
                to: next_state_name
            else
              # call the output function and return the value
              output = origin_state.output(input, ctx)
              {:ok, {next_state_name, output}}
            end

          # transition function returned error on given input
          :error ->
            {:error, {origin_state.name, input}}
        end
      end

      def start_link(ctx) do
        Agent.start_link(fn -> ctx end)
      end

      # return the machine's name
      def name, do: @machine_name

      @doc """
      Send a single event to the machine.
      """
      def event(machine, origin_state_name, input) do
        # get the machine's context
        ctx = Agent.get(machine, fn ctx -> ctx end)

        # pick the state, making sure it exists
        # then transition on given input
        origin_state = pick_state(origin_state_name)
        outcome = do_transition(origin_state, input, ctx)

        case outcome do
          # successfully called transition function
          {:ok, {next_state_name, output}} ->
            next_state = pick_state(next_state_name)
            substates = next_state.substates

            if Enum.any?(substates) do
              [initial_transition | _] = substates
              event(machine, initial_transition, output)
            else
              {:ok, {next_state_name, output}}
            end

          # error in transition function
          {:error, origin_state_name, input} ->
            {:error, origin_state_name, input}
        end
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
  machine and a starting state. Operator is responsible for keeping
  track of a machine's state.
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

      @doc """
      Updates the machine's current state.
      """
      def set_state(operator, next_state) do
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
          # successful transition
          {:ok, {next_state, output_value}} ->
            # store the machine's new state
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
