import { x } from "./x";

export interface Service {
  fetch(id: string): Promise<Item>;
  readonly name: string;
  onEvent?(e: Event): void
  onClick: (e: MouseEvent) => void;
}

/** Adds numbers. */
export function add(a: number, b: number = 1): number {
  return a + b;
}

export const multiply = (a: number, b: number): number => a * b;
const log = async (msg: string) => {
  console.log(msg);
};
const double = x => x * 2;
let legacy = function (y) { return y; };

export default class Widget<T> extends Base implements Service {
  #secret = 1;
  static count = 0;
  private cb: (x: number) => void;
  private handler = (e: Event): void => {
    this.fetch("x");
  };

  constructor(private readonly svc: Svc) {
    super();
  }

  async fetch(id: string): Promise<Item> {
    if (id) { return this.svc.get(id); }
    const re = /[{}]/g;
    return null as any;
  }

  get name(): string { return "w"; }
  set name(v: string) {}

  #hidden(): void {}

  overload(a: string): void;
  overload(a: number): void;
  overload(a: any): void {}
}

export abstract class Base {
  abstract render(): string;
  protected helper<T>(x: T): T { return x; }
}

module.exports.run = function (argv) { return 0; };
Foo.prototype.bar = function () {};

const api = {
  list() { return []; },
  create: async (x) => x,
  remove: function (id) { return id; },
};

describe("add", () => {
  it("works", () => { expect(add(1, 2)).toBe(3); });
});
