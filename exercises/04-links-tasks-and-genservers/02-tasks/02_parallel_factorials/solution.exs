defmodule Factorial do
  def calc(n), do: pcalc(n, 1)
  def pcalc(1, acc), do: acc
  def pcalc(n, acc), do: pcalc(n - 1, acc * n)
end

t1 = DateTime.utc_now()
Enum.map(1..4_000, &Factorial.calc(&1))
t2 = DateTime.utc_now()
diff = DateTime.diff(t2, t1, :millisecond)

# Now do this asynchronously with tasks and see how much faster it runs.
t3 = DateTime.utc_now()

tasks =
  Enum.map(
    1..4_000,
    fn n -> Task.async(fn -> Factorial.calc(n) end) end
  )

Task.yield_many(tasks, :infinity)
t4 = DateTime.utc_now()
diff2 = DateTime.diff(t4, t3, :millisecond)

IO.puts("SYNC: #{diff}ms vs ASYNC #{diff2}ms")
