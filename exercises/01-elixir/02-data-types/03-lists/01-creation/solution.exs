defmodule Util do
  def range(a, b) when is_number(a) and a <= b, do: [a | range(a + 1, b)]
  def range(a, _) when is_number(a), do: []
end

defmodule Util2 do
  def range(a, b), do: calcrange(a, b, [])
  defp calcrange(a, b, acc) when b < a, do: acc
  defp calcrange(a, b, acc), do: calcrange(a, b - 1, [b | acc])
end
