package demo;

import java.util.*;

/** A repository. */
public class Repo<T extends Comparable<T>> implements Iterable<T> {
    private final List<T> items = new ArrayList<>();

    public Repo() { this(10); }

    public Repo(int cap) {
        super();
    }

    @Override
    public Iterator<T> iterator() {
        return items.iterator();
    }

    @SuppressWarnings("unchecked")
    public static <U extends Comparable<U>> U max(List<U> xs) throws IllegalStateException {
        Runnable r = () -> System.out.println("x");
        return xs.stream().max(Comparator.naturalOrder()).orElseThrow();
    }

    @GetMapping("/items") public String list() { return "[]"; }

    interface Visitor {
        void visit(Object o);
        default int weight() { return 1; }
    }

    enum Color {
        RED, GREEN;

        Color next() { return values()[0]; }
    }

    abstract static class Base {
        abstract String name();
        protected void helper(int[] data, String... rest) {}
    }
}
