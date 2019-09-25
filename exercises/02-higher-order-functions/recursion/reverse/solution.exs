defmodule Exercise do
  def reverse([]), do: []
  def reverse([x|xs]), do: reverse(xs) ++ [x]
end

defmodule Exercise2 do
  def reverse(arg), do: preverse(arg, [])
  def preverse([], acc), do: acc |> List.flatten()
  def preverse([x | xs], acc), do: preverse(xs, [x | acc])
end
