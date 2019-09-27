Now that you know how to link processes, let's do this in practice. 

First write a simple module that lets you link the process to another one. Then spawn 4 of these processes and link them to each other.

```
A -> B -> C -> D -
^                 |
|-----------------
```

Then crash one of them, and confirm whether any one of them is still alive.

_Note: your `iex` shell should not crash!_