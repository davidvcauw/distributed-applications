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

### Context: factorials and triangular numbers

<!--
  Wat is het nut van deze paragraaf? Nergens wordt er op voortgebouwd.
  Het is nodeloos gedetailleerd. Best dit beperken tot "een zware berekening".
 -->

Let us start with a very simple factorial module (with tail-call optimization).

```elixir
defmodule Factorials do
    def calculate(n), do: calculate(n, 1)
    def calculate(1, acc), do: acc
    def calculate(n, acc), do: calculate(n - 1, acc * n)
end
```

_We'll use a benchmark module which will be explained later on._

Calculating the factorial of 50,000 will take a while: on my system it takes 1.7s. Imagine that we have to do something with this factorial as well as some other work,
such as computing the [triangular number](https://en.wikipedia.org/wiki/Triangular_number) of the same N value times 10,000.

```elixir
defmodule Triangular do
    def number(n), do: number(n, 0)
    def number(0, acc), do: acc
    def number(n, acc), do: number(n - 1, acc + n)
end
```

If we would do this synchronously then we'd spend 4.5-5s waiting, while only using one core to achieve this. This could easily be done asynchronously, considering both tasks have no need to interact/communicate with each other.

### `Task.async` and `Task.await`

First let us start a tedious task:

<!-- wat betekent "returning HI"? Is 't niet juist de bedoeling dat dit een zware berekening is? Waarom niet long_computation()? -->

```elixir
iex(1)> task = Task.async(fn -> "returning HI" end)
%Task{
    owner: #PID<0.105.0>,
    pid: #PID<0.177.0>,
    ref: #Reference<0.699843124.1838678017.129071>
}
```

<!-- Dit voelt lui aan. De bedoeling van een tekst is het uit te leggen, niet om te zeggen "je kan het zelf wel afleiden
     uit deze enkele regel code" -->

We've already covered references, pids and processes earlier so you should be able to understand what this means. In the end, the `Task` struct is nothing more than a simple abstraction to processes with some extra information.

If we want to retrieve the information, we just call `Task.await(task)`. Beware that this function will block your process until the timeout is finished. If you want to check multiple times if a task is already finished, consider using `Task.yield(task)`.

<!--
  "until timeout is finished" klinkt heel onlogisch. De term 'timeout' werd nergens geintroduceerd.
  Task.await blokkeert tot de task volledig uitgevoerd is voor zover ik weet. Een timeout verwijst normaalgezien naar iets anders.

  Voeg code toe die het gebruik van await en yield toont
-->

## A practical example

<!--
  Niet bepaald een logische gedachtengang. Wat heeft manueel pagina's afgaan te maken met async?
  Manueel afgaan van talloze pagina's kan vermeden worden door een script te schrijven.
  Het efficiënt maken van dit script kan met async.
-->

A perfect example of this would be web scraping, a tedious and exhausting thing that nobody wants to do. Now image doing this for a huge website - such as Amazon - and you don't want to waste time by waiting for the response. Then parallelizing your requests would be a lot more effective (just don't DOS your target...). As an example we'll use `intranet.ucll.be`, as they won't mind that we send a lot of requests in a short time.

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

<!--
  Ik begrijp de logica niet. Negeer de lege lijsten omdat andere libraries het eenvoudiger kunnen?
  Waarom dan niet een van die eenvoudigere libraries gebruiken?
-->

Don't worry about the empty lists passed as parameters, because other libraries are easier to understand. If you successfully see the response, let's send 200 requests after each other and see how long this takes. _I'm putting a timer.sleep in here so that the effect is amplified._

<!--
  Voorbeeld is bijzonder geforceerd:
  * De sleep maakt de request nutteloos.
  * Als we realistisch zouden scrapen, zou de sleep ervoor dienen om de requests wat uit te spreiden. Werken met async maakt dat weer ongedaan.
  * Het voelt aan als een excuus om intranet lastig te vallen, maar er is geen enkele reden voor. Het zou logischer zijn terug te vallen op de triangular van hierboven.
-->

```elixir
def request_intranet() do
  :httpc.request(:get, {'http://intranet.ucll.be', []}, [], [])
end

def request_intranet_200_times() do
    Enum.map(1..200, fn _ ->
        :timer.sleep(100)
        request_intranet()
    end
end

Benchmark.measure(&request_intranet_200_times/0)
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
