defmodule TransitionError do
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

defmodule StateError do
  @moduledoc """
  Tried to access a state id that does not exist.
  """

  defexception [:state_id]

  def message(%{state_id: state_id}) do
    "state '#{state_id}' does not exist"
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

  defmacro __using__(id: id, to: to, substates: substates) do
    quote bind_quoted: [id: id, to: to, substates: substates] do
      @behaviour State

      @state_id id
      @neighbours to
      @substates substates

      def id, do: @state_id
      def to, do: @neighbours
    end
  end
end

defmodule Machine do
  @moduledoc """
  Template for a finite state machine.
  """

  defmacro __using__(name: name, states: states) do
    quote bind_quoted: [name: name, states: states] do
      import Machine

      use GenServer

      @name name
      @states states
      @before_compile Machine

      def start_link(ctx) do
        GenServer.start_link(__MODULE__, ctx)
      end

      def init(ctx) do
        {:ok, ctx}
      end

      # handle event messages
      def handle_call({:event, state_id, input}, _, ctx) do
        # pick the state, making sure it exists
        state =
          case @states[state_id] do
            nil -> raise StateError, state_id: state_id
            state -> state
          end

        # transition on given input
        outcome =
          case state.transition(input, ctx) do
            # successful transition if the next state is
            # allowed otherwise raise TransitionError
            {:ok, next_state} ->
              if next_state not in state.to do
                raise TransitionError,
                  from: state_id,
                  to: next_state,
                  allowed: state.to
              else
                {:ok, {next_state, state.output(input, ctx)}}
              end

            # the transition function returned an error on
            # the given input
            :error ->
              {:error, {state, input}}
          end

        # respond to the caller
        {:reply, outcome, ctx}
      end

      # handle routine messages
      def handle_call({:routine, routine_name, input}, _, ctx) do
        # do work here
        # ...

        outcome = :error

        # respond to the caller
        {:reply, outcome, ctx}
      end

      @doc """
      Send a single event to the machine.
      """
      def event(machine, state_id, input) do
        GenServer.call(machine, {:event, state_id, input})
      end

      @doc """
      Call a pre-defined routine on a given input.
      """
      def routine(machine, routine_name, input) do
        GenServer.call(machine, {:routine, routine_name, input})
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
    end
  end

  defmacro routine(name, do: block) do
    function_name = String.to_atom(name)

    quote do
      def unquote(function_name)(), do: unquote(block)
    end
  end
end
