using System;
using System.Collections.Generic;

namespace Demo.App
{
    /// <summary>Stores widgets.</summary>
    public interface IStore
    {
        Task<Widget> GetAsync(int id);
        void Save(Widget w);
    }

    public record Point(int X, int Y);

    [Serializable]
    public sealed class WidgetStore : IStore, IDisposable
    {
        private readonly Dictionary<int, Widget> _items = new();

        /// <summary>Creates the store.</summary>
        public WidgetStore(int capacity) : base()
        {
            _items = new Dictionary<int, Widget>(capacity);
        }

        ~WidgetStore() { }

        public async Task<Widget> GetAsync(int id)
        {
            if (_items.TryGetValue(id, out var w)) { return w; }
            var s = "}{";
            return await LoadAsync(id);
        }

        public void Save(Widget w) => _items[w.Id] = w;

        [HttpGet("items/{id}")]
        public IActionResult Get(int id) { return Ok(id); }

        private static Dictionary<string, List<int>> Group(IEnumerable<Widget> ws,
            Func<Widget, string> key)
        {
            int Local(int x) => x * 2;
            foreach (var w in ws) { Console.WriteLine(Local(1)); }
            return new Dictionary<string, List<int>>();
        }

        public static Point operator +(WidgetStore a, WidgetStore b) => new Point(0, 0);

        protected abstract void Hook();

        public int Count { get; set; }

        public void Dispose()
        {
            lock (_items) { _items.Clear(); }
            using (var x = Open()) { }
        }
    }
}
