# shellcheck shell=bash
# Shared by the create-plan fixtures; sourced, not run. Builds a small Node
# shop API that matches the template's example content: GitHub issues for
# tickets, HTTP endpoints and an SQL schema for contracts, and no plans folder
# yet, so plans go to .agents/plans/. The code calls the shopping cart a
# Basket, and LineItem is shared by baskets and orders. Committed on main and
# pushed. Leaves the current folder at the repository.

# shellcheck source=scripts/evals/fixture-lib.sh
. "$EVAL_LIB"

shop_base() {
	local root="$1"
	eval_repo "$root"
	cd "$root/repo" || return

	cat >package.json <<'EOF'
{
	"name": "shop",
	"version": "1.0.0",
	"type": "module",
	"scripts": {
		"start": "node src/server.js",
		"test": "node --test"
	}
}
EOF
	cat >README.md <<'EOF'
# shop

The HTTP API behind the shop: customers, their basket, checkout and orders.
EOF
	cat >AGENTS.md <<'EOF'
# Working in this repo

- One folder per area under `src/` (`customers`, `basket`, `orders`), each with its domain classes and a repository over the database.
- Routes are in `src/routes.js`; the schema is `db/schema.sql`, changed only through a new file in `db/migrations/`.
- Tests are in `test/`, run with `npm test`. Every route change comes with a test that calls the route.
- Tickets are GitHub issues.
EOF
	mkdir -p src/customers src/basket src/orders db/migrations test

	cat >src/customers/customer.js <<'EOF'
export class Customer {
	constructor(id, email) {
		this.id = id;
		this.email = email;
	}
}
EOF
	cat >src/orders/line-item.js <<'EOF'
// One product in a basket or an order, with the price it had when added.
export class LineItem {
	constructor(productId, quantity, unitPriceCents) {
		this.productId = productId;
		this.quantity = quantity;
		this.unitPriceCents = unitPriceCents;
	}

	totalCents() {
		return this.quantity * this.unitPriceCents;
	}
}
EOF
	cat >src/orders/order.js <<'EOF'
export const OrderStatus = Object.freeze({
	PLACED: "placed",
	PAID: "paid",
	SHIPPED: "shipped",
	DELIVERED: "delivered",
	CANCELLED: "cancelled",
});

export class Order {
	constructor(id, customerId, lineItems, status = OrderStatus.PLACED) {
		this.id = id;
		this.customerId = customerId;
		this.lineItems = lineItems;
		this.status = status;
	}

	totalCents() {
		return this.lineItems.reduce((sum, item) => sum + item.totalCents(), 0);
	}
}
EOF
	cat >src/basket/basket.js <<'EOF'
import { LineItem } from "../orders/line-item.js";

// What a customer means to buy, before checkout. One per customer.
export class Basket {
	constructor(customerId, lineItems = []) {
		this.customerId = customerId;
		this.lineItems = lineItems;
	}

	add(productId, quantity, unitPriceCents) {
		this.lineItems.push(new LineItem(productId, quantity, unitPriceCents));
	}

	clear() {
		this.lineItems = [];
	}
}
EOF
	cat >src/basket/basket-repository.js <<'EOF'
import { Basket } from "./basket.js";

export class BasketRepository {
	constructor(db) {
		this.db = db;
	}

	async forCustomer(customerId) {
		const rows = await this.db.query("select * from basket_items where customer_id = $1", [customerId]);
		const basket = new Basket(customerId);
		for (const row of rows) {
			basket.add(row.product_id, row.quantity, row.unit_price_cents);
		}
		return basket;
	}

	async save(basket) {
		await this.db.query("delete from basket_items where customer_id = $1", [basket.customerId]);
		for (const item of basket.lineItems) {
			await this.db.query(
				"insert into basket_items (customer_id, product_id, quantity, unit_price_cents) values ($1, $2, $3, $4)",
				[basket.customerId, item.productId, item.quantity, item.unitPriceCents],
			);
		}
	}
}
EOF
	cat >src/routes.js <<'EOF'
// GET  /basket            the signed-in customer's basket
// POST /basket/items      add { productId, quantity } to it
// POST /checkout          turn the basket into an order and empty it
// GET  /orders/:id        one of the customer's orders
export function routes({ baskets, orders, prices }) {
	return {
		"GET /basket": async (req) => baskets.forCustomer(req.customerId),
		"POST /basket/items": async (req) => {
			const basket = await baskets.forCustomer(req.customerId);
			basket.add(req.body.productId, req.body.quantity, await prices.current(req.body.productId));
			await baskets.save(basket);
			return basket;
		},
		"POST /checkout": async (req) => {
			const basket = await baskets.forCustomer(req.customerId);
			const order = await orders.place(req.customerId, basket.lineItems);
			basket.clear();
			await baskets.save(basket);
			return order;
		},
		"GET /orders/:id": async (req) => orders.find(req.customerId, req.params.id),
	};
}
EOF
	cat >db/schema.sql <<'EOF'
create table customers (id text primary key, email text not null unique);
create table orders (id text primary key, customer_id text not null references customers, status text not null);
create table order_items (order_id text not null references orders, product_id text not null, quantity int not null, unit_price_cents int not null);
create table basket_items (customer_id text not null references customers, product_id text not null, quantity int not null, unit_price_cents int not null);
EOF
	cat >test/basket.test.js <<'EOF'
import { test } from "node:test";
import assert from "node:assert/strict";
import { Basket } from "../src/basket/basket.js";

test("a basket adds up what was added to it", () => {
	const basket = new Basket("c1");
	basket.add("p1", 2, 150);
	assert.equal(basket.lineItems[0].totalCents(), 300);
});
EOF
	eval_commit . "feat: customers, baskets, checkout and orders"
}

# The glossary: Customer and Order defined, LineItem missing, and basket
# against cart left as an open naming decision. No rules for adding terms, so
# the template's glossary guide applies.
shop_glossary() {
	cat >GLOSSARY.md <<'EOF'
# Glossary

The shop's domain terms, and the names the code uses for them.

## Terms

### Customer

Someone with an account, who can keep a basket and place orders. Guests check out without one and are not customers. Code: `Customer` ([src/customers/customer.js](src/customers/customer.js)).

### Order

A customer's confirmed purchase, from checkout until it is delivered or cancelled. Its states are `OrderStatus`: placed, paid, shipped, delivered, cancelled. Code: `Order` ([src/orders/order.js](src/orders/order.js)).

## Open naming decisions

- **Basket or cart:** the code calls it `Basket` (`src/basket/`, the `basket_items` table, the `/basket` routes), while the shop's pages and support say _cart_. Proposal: _cart_.
EOF
	cat >>AGENTS.md <<'EOF'
- The domain's agreed names are in `GLOSSARY.md`.
EOF
	eval_commit . "docs: start a glossary"
}
