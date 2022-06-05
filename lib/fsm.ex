defmodule TransitionError do
  @moduledoc """
  Transition function tried to move to a state
  outside of its "to" list.
  """

  defexception [:from, :to, :allowed]

  def message(%{from: from, to: to, allowed: allowed}) do
    "invalid transition #{from} -> #{to}, allowed: #{allowed}"
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
      @id id
      @to to
      @substates substates
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

      def start_link(ctx) do
        GenServer.start_link(__MODULE__, ctx)
      end

      def init(ctx) do
        {:ok, ctx}
      end

      # handle event messages
      def handle_call({:event, state_id, input}, _, ctx) do
        # pick the state
        state = @states[state_id]

        # transition on given input
        case state.transition(input, ctx) do
          # successful transition if the next state is allowed
          # otherwise raise TransitionError
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
      end

      # handle routine messages
      def handle_call({:routine, routine_name, input}, _, ctx) do
        # do work here
        # ...

        :error
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

  defmacro routine(name, do: block) do
    function_name = String.to_atom(name)

    quote do
      def unquote(function_name)(), do: unquote(block)
    end
  end
end
