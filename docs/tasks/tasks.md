---
layout: default
---
# Tasks

_We are using terminology normally used in the Erlang / Elixir context. When we talk about OS-related terminology, we will specifically mention this._

## Tasks vs processes

Tasks are an abstraction to normal processes, meant to easily execute asynchronous compute-intensive operations and await for their response.

They normally require no communication, and also provide a useful API to do different operations.

## An asynchronous task with a reply

There are different kinds of tasks, but let us start with the most basic form: a task that gives a response.

### Context: factorials

Let us start with a very simple factorial module (with tail-call optimization).

```elixir
defmodule Factorials do
    def calculate(n), do: calculate(n, 1)
    def calculate(1, acc), do: acc
    def calculate(n, acc), do: calculate(n - 1, acc * n)
end
```
s
_We'll use a benchmark module which will be explained later on._

Calculating the factorial of 50,000 will take a while: on my system it takes 1.7s. Imagine that we offer a platform / API to calculate one or more factorials at the same time. The user gives a set of numbers (in e.g. a web browser), then has to wait until all the factorials have been calculated synchronously. This will take a lot of time for no reason, while we can do this easily asynchronously. Note that these asynchronous tasks have no need to communicate with each other, which is the easiest form of asynchronous computing

### `Task.async` and `Task.await`

First let us start a tedious task:
{% raw %}
```elixir
iex(1)> t =
...(1)>   Task.async(fn ->
...(1)>     :timer.sleep(10_000)
...(1)>     "Returning hi"
...(1)>   end)
%Task{
  owner: #PID<0.105.0>,
  pid: #PID<0.111.0>,
  ref: #Reference<0.1392272653.3360948226.102954>
}
```
{% endraw %}

A short revision here: 
 * %Task{...} is a struct. This is just a bare map underneath. Operations such as `Map.get` or `Map.fetch` work without any problems.
 * PID is just the process identifier. We can use this to, if necessary, send messages to the task.
 * A reference is a special data type with a unique value. It's great for e.g. tagging messages and recognizing if the message we received is the response to the question you sent.
In the end, the `Task` struct, or map, is nothing more than a simple abstraction to processes with some extra information.

In the above task, which is just an example to see how we can collect an output from a task, the last value emitted is "returning HI". This result can be collected with `Task.await(task)`. Sample usage would be:

```elixir
iex(2)> Task.await(t, 10000)
"Returning hi"
```

The first argument is the task struct, while the second is a timeout value. The timeout is meant to provide guarantees to the user that they'll get a response within X milliseconds. An example could be that a user with malicious intentions inserts extremely high numbers in your Factorial calculation website, in the hopes to crash your system, but thanks to the timeout you can define how much seconds one task may take. 

`Task.await` is blocking, thus halting code execution. If you use Task.await, you can only call this once, if you'd prefer to call this more often, you can call this multiple times with `Task.yield`. 

#### Going in-depth with `Task.yield`

To demonstrate the usage and benefits of `Task.yield`, we'll write a module that executes specific code until the task is finished. 

```elixir
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
```

In the `MyTaskChecker.check` function we specifically check whether a Task struct, or map, has been passed. After that we define our timeout limit, print a quick message, and try our first yield. If the yield is successful, the first `MyTaskChecker.report` will fail, as the result is not nil, and the second clause will just return the result. 

Of course this code is to illustrate a task that takes 20 seconds, while we check every 3 seconds. When we call `Task.yield` and there is no result yet, it'll return nil. Then the first `MyTaskChecker.report` clause will match, print a message and try `Task.yield` again. When it is finished it'll return the result. To see this is in action:

```
iex> MyTaskChecker.check(t)
Start periodic checking for task with PID #PID<0.406.0>
Checking again
Checking again
Checking again
Checking again
Checking again
Checking again
{:ok, "Finished"}
```
As you can see, this is perfect to execute code while waiting for your task to finish.

## Building our factorial API

Let us build a simple wrapper around our Factorial module. This way we can calculate the factorials for a whole list, and see the use `Task.yield_many`.

Considering we already have most of our code (the logic) of our FactorialAPI, we can just focus on the "interface" module. Though in order to protect our fictive server on which this code will run, we're going to provide a timeout based on the completion time of the complete list.

To put it into perspective, imagine a list with the elements
[1,4,6,7,9,9999999999999999999999]. We can immediately see which which factorials can be calculated within a given time frame, and which cannot. In this case, we'll just return the factorials of the elements which we can calculate and an error for those which are too big.

```elixir
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
```

{% raw %}
The FactorialAPI has one public entry point, the `calculate_list` function. We start a task for each number in the list, after which they are collected by `Task.yield_many` with a timeout of 2 seconds. Every task in the list called "tasks", will return a tuple existing of {%Task{}, _response_} where the first element is the Task struct and the second the response. The response can be {:ok, _value_} but nil as well. When the task is still running, it'll return nil.
{% endraw %}

Sample usage of this module would be:

```elixir
iex> FactorialAPI.calculate_list([1, 2, 3, 999_999_999_999])
[1, 2, 6, {:error, :timeout_exceeded}]
```

Where you can see that the `process_task_output` function pattern matches on the output. Keep in mind that if the tasks is still running, we have to kill it manually. That is what the `Task.shutdown` is for. The `:brutal_kill` argument is the exit signal. 

_There are several exit signals. When using `Task.shutdown` you can also pass a timeout instead of the exit signal, which will send the :shutdown exit signal after the timeout. In our case, we don't want to wait and just kill it straight away. Hence the `:brutal_kill` argument._