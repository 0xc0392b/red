# example replicated state machine
defmodule RSMTest.Machine do
  use ReplicatedStateMachine

  # do work here
  # ...
end

# test distributed log
defmodule RSMTest.DistributedLogTest do
  use ExUnit.Case
  doctest Machine

  test "create example distributed log" do
    # create distributed log with empty in-memory store
    {:ok, pid} =
      DistributedLog.start_link(
        storage_backend: StorageBackend.InMemory,
        storage_options: [],
        participants: [:a]
      )

    # get the latest value added to the log
    latest = DistributedLog.latest(pid)

    # get all entries
    all_entries = DistributedLog.replay(pid, nil)

    assert latest == :empty and
             all_entries == :empty
  end

  test "append to a log" do
    # do work here
    # ...

    true
  end

  test "get a log's latest entry" do
    # do work here
    # ...

    true
  end

  test "replay a log from a given starting point" do
    # do work here
    # ...

    true
  end
end

# test example state machine
defmodule RSMTest.MachineTest do
  use ExUnit.Case
  doctest Machine

  test "create example replicated state machine" do
    # do work here
    # ...
  end
end
