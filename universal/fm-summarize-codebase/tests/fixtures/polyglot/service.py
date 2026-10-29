"""Module doc."""
import functools


class Service:
    """A service."""

    def __init__(self, url: str) -> None:
        self.url = url

    @property
    def host(self) -> str:
        """The host."""
        return self.url

    @host.setter
    def host(self, value):
        self.url = value

    @staticmethod
    def parse(text, *args, sep=",", **kw):
        def inner(x):
            return x
        return [inner(t) for t in text.split(sep)]

    async def fetch(self):
        return await self._get()

    async def _get(self):
        return 1


square = lambda x: x * x


def test_parse():
    assert Service.parse("a,b") == ["a", "b"]
