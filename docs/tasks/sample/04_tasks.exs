defmodule Benchmark do
  def measure(function) do
    function
    |> :timer.tc()
    |> elem(0)
    |> Kernel./(1_000_000)
  end
end

defmodule Factorials do
  def calculate(n), do: calculate(n, 1)
  def calculate(1, acc), do: acc
  def calculate(n, acc), do: calculate(n - 1, acc * n)
end

defmodule Triangular do
  def number(n), do: number(n, 0)
  def number(0, acc), do: acc
  def number(n, acc), do: number(n - 1, acc + n)
end

# Synchronous
fn ->
  Factorials.calculate(50_000)
  Triangular.number(50_000 * 10_000)
end
|> Benchmark.measure()

Application.ensure_all_started(:inets)
Application.ensure_all_started(:ssl)

fn ->
  tasks =
    Enum.map(1..200, fn _ ->
      Task.async(fn ->
        :timer.sleep(100)
        :httpc.request(:get, {'http://intranet.ucll.be', []}, [], [])
      end)
    end)

  Task.yield_many(tasks, 60_000)
end
|> Benchmark.measure()

fn ->
  Enum.map(1..200, fn _ ->
    :timer.sleep(100)
    :httpc.request(:get, {'http://intranet.ucll.be', []}, [], [])
  end)
end
|> Benchmark.measure()

defmodule MyTaskChecker do
  def check(%Task{} = t) do
    timeout = 3_000
    IO.puts("Start periodic checking for task with PID #{inspect(t.pid)}")
    result = Task.yield(t, timeout)
    report(t, timeout, result)
  end

  defp report(%Task{} = t, timeout, nil) do
    IO.puts("Checking again")
    result = Task.yield(t, timeout)
    report(t, timeout, result)
  end

  defp report(_t, _timeout, result), do: result
end

t =
  Task.async(fn ->
    :timer.sleep(20_000)
    "Finished"
  end)

MyTaskChecker.check(t)

defmodule Factorials do
  def calculate(n), do: calculate(n, 1)
  def calculate(1, acc), do: acc
  def calculate(n, acc), do: calculate(n - 1, acc * n)
end

defmodule FactorialAPI do
  def calculate_list(l) when is_list(l) do
    tasks = Enum.map(l, &Task.async(fn -> Factorials.calculate(&1) end))
    results = Task.yield_many(tasks, 2_000)
    Enum.map(results, &process_task_output/1)
  end

  defp process_task_output({t, nil}) do
    Task.shutdown(t, :brutal_kill)
    {:error, :timeout_exceeded}
  end

  defp process_task_output({_t, {:ok, resp}}), do: resp
end

FactorialAPI.calculate_list([1, 2, 3, 999_999_999_999])
