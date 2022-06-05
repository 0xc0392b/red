defmodule State do
  @moduledoc """
  Template for a state.
  """

  defmacro __using__(id: id, to: to, substates: substates) do
    quote bind_quoted: [id: id, to: to, substates: substates] do
      import State

      @id id
      @to to
      @substates substates
    end
  end

  defmacro transition(do: block) do
    quote do
      def transition({:event, input}) do
        unquote(block)
      end
    end
  end

  defmacro output(do: block) do
    quote do
      def output({:event, input}) do
        unquote(block)
      end
    end
  end
end

defmodule Machine do
  @moduledoc """
  Template for a finite state machine.
  """

  defmacro __using__(name: name, states: states) do
    # build transition matrix at compile-time
    # ...

    quote do
      use GenServer

      # inline the matrix
      # ...

      defp transition(state, input) do
        # do work here
        # ...

        :error
      end

      defp output(state, input) do
        # do work here
        # ...

        :none
      end

      def start_link(init_arg) do
        GenServer.start_link(__MODULE__, init_arg)
      end

      def init(init_arg) do
        {:ok, init_arg}
      end

      def handle_call({:event, state_id, input}, _, init_arg) do
        # pick state
        # ...

        case transition(state, input) do
          # successful transition
          {:ok, next_state} ->
            {:ok, {next_state, output(state, input)}}

          # error on (state, input)
          :error ->
            {:error, {state, input}}
        end
      end

      def handle_call({:routine, routine_name, input}, _, init_arg) do
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
