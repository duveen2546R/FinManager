// Domain helpers. (In the TypeScript version this file also held the
// Transaction / navigation param types; in plain JS only the runtime
// converter remains.)

// Converts the raw JSON shape returned by the Flask backend into a
// normalized transaction object with a real Date.
export function transactionFromJson(json) {
  return {
    id: json.transaction_id,
    title: json.title,
    description: json.description,
    category: json.category,
    amount: parseFloat(String(json.amount)),
    type: json.transaction_type,
    date: new Date(json.date),
  };
}
