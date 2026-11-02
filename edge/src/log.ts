/** Structured JSON logs (Workers Logs indexes the fields). Never log tokens or user ids in clear. */
export function logError(event: string, error: unknown, extra: Record<string, unknown> = {}): void {
  console.log(
    JSON.stringify({
      level: 'error',
      event,
      ...extra,
      error: error instanceof Error ? { name: error.name, message: error.message } : String(error),
    }),
  );
}

export function logInfo(event: string, extra: Record<string, unknown> = {}): void {
  console.log(JSON.stringify({ level: 'info', event, ...extra }));
}
