ExUnit.start()

file = System.get_env("DA_TESTFILE") || "student.exs"
Code.load_file(file, __DIR__)


defmodule Aux do
  defmacro check(that: block, is_equal_to: expected) do
    str = Macro.to_string(block)
    quote do
      test "#{unquote(str)} should be equal to #{unquote(expected)}" do
        assert unquote(block) == unquote(expected)
      end
    end
  end
end

defmodule Tests do
  use ExUnit.Case, async: true
  import Aux


  check that: Fibonacci.fib(0), is_equal_to: 0
  check that: Fibonacci.fib(1), is_equal_to: 1
  check that: Fibonacci.fib(2), is_equal_to: 1
  check that: Fibonacci.fib(3), is_equal_to: 2
  check that: Fibonacci.fib(4), is_equal_to: 3
  check that: Fibonacci.fib(5), is_equal_to: 5
  check that: Fibonacci.fib(6), is_equal_to: 8
  check that: Fibonacci.fib(7), is_equal_to: 13
end
