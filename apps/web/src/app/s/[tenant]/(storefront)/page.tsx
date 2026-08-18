export default async function StorefrontHome({
  params,
}: {
  params: Promise<{ tenant: string }>;
}) {
  const { tenant } = await params;

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-4 p-8 text-center">
      <h1 className="font-display text-4xl font-semibold text-ink-900">
        {tenant}.tokospace.com
      </h1>
      <p className="max-w-md text-ink-600">
        Storefront placeholder — served at any *.tokospace.com subdomain.
        Real tenant resolution/validation against Laravel is built in Tahap
        1, not here.
      </p>
    </main>
  );
}
