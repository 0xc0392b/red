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
      use GenServer

      import Machine

      @name name
      @states states

      # build and inline transition matrix at compile-time
      @before_compile Machine

      defp transition([], input), do: {:error, input}

      defp transition([state | remaining], input) do
        # transition on given input
        case state.transition(input, ctx) do
          # successful transition
          {:ok, next_state} ->
            {:ok, {next_state, state.output(input, ctx)}}

          # error on (state, input)
          :error ->
            {:error, {state, input}}
        end
      end

      def start_link(ctx) do
        GenServer.start_link(__MODULE__, ctx)
      end

      def init(ctx) do
        {:ok, ctx}
      end

      # handle event messages
      def handle_call({:event, state_id, input}, _, ctx) do
        # the set of possible destination states
        possible_states = @matrix[state_id]

        # try to resolve
        transition(possible_states, input)
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

  defmacro __before_compile__(_env) do
    matrix =
      for state <- @states do
        from = state.id

        # TODO
        # this needs to be recursive
        # constructed inner-mode -> outer-most
        first_try = for dest in state.substates, do: dest.id

        # out-going edges
        then_try = for dest in state.to, do: dest.id
        to = first_try ++ then_try

        {from, to}
      end
      |> Enum.into(%{})

    quote bind_quoted: [matrix: matrix] do
      @matrix = matrix
    end
  end

  defmacro routine(name, do: block) do
    function_name = String.to_atom(name)

    quote do
      def unquote(function_name)(), do: unquote(block)
    end
  end
end
