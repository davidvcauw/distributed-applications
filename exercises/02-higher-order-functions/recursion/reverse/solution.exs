defmodule Exercise do
  def reverse([]), do: []
  def reverse([x | xs]), do: reverse(xs) ++ [x]
end

defmodule Exercise2 do
  def reverse(arg), do: preverse(arg, [])
  def preverse([], acc), do: acc |> List.flatten()
  def preverse([x | xs], acc), do: preverse(xs, [x | acc])
end

defmodule Benchmark do
  def measure(function) do
    function
    |> :timer.tc()
    |> elem(0)
    |> Kernel./(1_000_000)
  end
end

defmodule Random do
  def random_array(length, list \\ [])
  def random_array(0, list), do: list
  def random_array(length, list), do: random_array(length - 1, [random_number() | list])
  def random_number(), do: :rand.uniform(1000)
end

n = Random.random_array(2_000_000)
t1 = Benchmark.measure(fn -> Exercise.reverse(n) end)
t2 = Benchmark.measure(fn -> Exercise2.reverse(n) end)
