package store

// Store keeps things.
type Store struct {
	items map[string]int
}

type Getter interface {
	Get(key string) (int, bool)
	Len() int
}

// NewStore creates a store.
func NewStore() *Store {
	return &Store{items: map[string]int{}}
}

// Get returns an item.
func (s *Store) Get(key string) (int, bool) {
	v, ok := s.items[key]
	return v, ok
}

func (s Store) Len() int { return len(s.items) }

func Map[T any, U any](xs []T, f func(T) U) []U {
	out := make([]U, 0, len(xs))
	for _, x := range xs {
		out = append(out, f(x))
	}
	return out
}

func weird(x interface{}) interface{} {
	helper := func() {}
	helper()
	return x
}

func TestStore(t *testing.T) {}
