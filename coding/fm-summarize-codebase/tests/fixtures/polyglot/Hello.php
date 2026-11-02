<?php
namespace App;

interface Greeter
{
    public function greet(string $name): string;
}

abstract class Base
{
    abstract protected function tag(): string;
}

final class Hello extends Base implements Greeter
{
    public function __construct(private string $prefix = "Hi") {}

    /** Greets someone. */
    public function greet(string $name): string
    {
        $f = function ($x) { return $x; };
        $g = fn($y) => $y * 2;
        return "{$this->prefix} {$name}";
    }

    protected function tag(): string { return 'hello'; }

    public static function make(): static { return new static(); }
}

function helper(array $xs = []): int { return count($xs); }
