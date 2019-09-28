---
layout: default
---
# Tasks

_We are using terminology normally used in the Erlang / Elixir context. When we talk about OS-related terminology, we will specifically mention this._

## Tasks vs processes

Tasks are an abstraction to normal processes, meant to easily execute asynchronous compute-intensive operations and await for their response.

They normally require no communication, and also provide a useful API to do different operations.

## An asynchronous task with a reply

There are different kind of tasks, but let us start with the most basic form. A task that gives a response.

### Context: factorials and triangular numbers

Let us start with a very simple factorial module (with tail-call optimization).

```elixir
defmodule Factorials do
    def calculate(n), do: calculate(n, 1)
    def calculate(1, acc), do: acc
    def calculate(n, acc), do: calculate(n - 1, acc * n)
end
```

_We'll use a benchmark module which will be explained later on._

Calculating the factorial of 50 000 will take a while, on my system it takes 1.7s. Image that we have to do something with this factorial, but also some other work. For example also the [triangular number](https://en.wikipedia.org/wiki/Triangular_number) of the same N value times 10 000.

```elixir
defmodule Triangular do
    def number(n), do: number(n, 0)
    def number(0, acc), do: acc
    def number(n, acc), do: number(n - 1, acc + n)
end
```

If we would do this synchronously then we'd spend 4.5-5s waiting, while only using one core to achieve this. This could easily be done asynchronously, considering both tasks have no need to interact / communicate with each other.

### `Task.async` and `Task.await`

First let us start a tedious task:

```elixir
iex> Task.async fn -> "returning HI" end
%Task{
    owner: #PID<0.105.0>,
    pid: #PID<0.177.0>,
    ref: #Reference<0.699843124.1838678017.129071>
}
```

We've already covered references, pids and processes earlier so you should be able to understand what this means. In the end, the Task struct is nothing more than a simple abstraction to processes with some extra information.

If we want to retrieve the information, we just call Task.await. Beware that this function will block your process until the timeout is finished. If you want to check multiple times if a task is already finished, consider using `Task.yield`.

## A practical example

A perfect example of this would be web scraping, a tedious and exhausting thing that nobody wants to do. Now image doing this for a huge website - such as amazon - and you don't want to waste time by waiting for the response. Then parallelizing your requests would be a lot more effective (just don't DOS your target...). As an example we'll use intranet.ucll.be , as they won't mind that we send a lot of requests in a short time.

For this we'll use the erlang HTTP client. Take note that this is just for educative purposes, and in production you'll want a full fledged HTTP client library to take care of strange situations.

To be able to use this, we'll do a little bit of preparation. First enable the inets module, and compile the following module:

```elixir
defmodule Benchmark do
    def measure(function) do
    function
        |> :timer.tc
        |> elem(0)
        |> Kernel./(1_000_000)
    end
end
Application.ensure_all_started(:inets)
```

Execute a simple request to see that you can access the website:

```elixir
:httpc.request(:get, {'http://intranet.ucll.be', []}, [], []) end)
```

Don't worry about the empty parameters, because other libraries are easier to understand. If you successfully see the response, let's send 200 requests after each other and see how long this takes. _I'm putting a timer.sleep in here so that the effect is amplified._

```elixir
fn ->
    Enum.map(1..200, fn _ ->
        :timer.sleep(100)
        :httpc.request(:get, {'http://intranet.ucll.be', []}, [], [])
    end)
end |> Benchmark.measure()
```

This will take around 23 seconds on my system. We can wrap this in a task and send all the requests parallel, which we can collect later on.

```elixir
fn ->
    tasks =
    Enum.map(1..200, fn _ ->
        Task.async(fn ->
            :timer.sleep(100)
            :httpc.request(:get, {'http://intranet.ucll.be', []}, [], [])
        end)
    end)

    Task.yield_many(tasks, 60_000)
end |> Benchmark.measure()
```

Try to yield these tasks and you'll see the response. Instead of 23 seconds, it is done in merely 7-8s.
