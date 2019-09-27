defmodule Factorial do
  def calc(n), do: pcalc(n, 1)
  def pcalc(1, acc), do: acc
  def pcalc(n, acc), do: pcalc(n - 1, acc * n)
end

t1 = DateTime.utc_now()
Enum.map(1..4_000, &Factorial.calc(&1))
t2 = DateTime.utc_now()
diff = t2 - t1

# Now do this asynchronously with tasks and see how much faster it runs.
