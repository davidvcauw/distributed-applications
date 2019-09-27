# Basic syntax
Task.async(fn -> :ok1 end)
Task.async(fn -> :ok2 end)
Task.async(fn -> :ok3 end)

defmodule Receive do
  def message() do
    receive do
      {ref, val} ->
        IO.puts("I've received #{inspect(val)} form #{inspect(ref)}")

      {:DOWN, ref, :process, pid, :normal} ->
        IO.puts("Normal process exit form #{inspect(pid)} with ref #{inspect(ref)}")
    end

    message()
  end
end

# either spawn a process that prints to the screen or block your iex shell.. up to you
Receive.message()

############################
# FUN version             ##
############################
tasks = Enum.map(1..100, fn n -> Task.async(fn -> {:ok, n} end) end)

myreceive = fn f ->
  receive do
    {ref, val} ->
      IO.puts("I've received #{inspect(val)} form #{inspect(ref)}")

    {:DOWN, ref, :process, pid, :normal} ->
      IO.puts("Normal process exit form #{inspect(pid)} with ref #{inspect(ref)}")
  end

  f.(f)
end

myreceive.(myreceive)

# After looking at this code, you should be able to understand what is happenning.
# NOTE: There is no guarantee in which order the results arrive!
