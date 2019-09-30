defmodule Demo do
  require IEx

  def debug_in_fuction() do
    xs = [1, 2, 3]
    IEx.pry()
    xs_mapped = Enum.map(xs, &(&1 * 2))
    IEx.pry()
    {higher, _lower} = Enum.split_with(xs_mapped, &(&1 > 5))
    IEx.pry()
  end
end
