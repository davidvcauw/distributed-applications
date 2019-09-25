defmodule Util do
  def range(a, b) when is_number(a) and a <= b, do: [a | range(a + 1, b)]
  def range(a, _) when is_number(a), do: []
end

defmodule Util2 do
  def range(a, b), do: calcrange(a, b, [])
  defp calcrange(a, b, acc) when b < a, do: acc
  defp calcrange(a, b, acc), do: calcrange(a, b - 1, [b | acc])
end

defmodule Benchmark do
  def measure(function) do
    function
    |> :timer.tc()
    |> elem(0)
    |> Kernel./(1_000_000)
  end
end

start = 0
stop = 200_000_000
t1 = Benchmark.measure(fn -> Util.range(start, stop) end)
t2 = Benchmark.measure(fn -> Util2.range(start, stop) end)
