import { NextRequest, NextResponse } from "next/server";

/**
 * Host-based routing per Tech Spec §3/§4: one Next.js app serves marketing
 * (apex), seller dashboard (app.*), tenant storefronts (*.tokospace.com),
 * and super admin (admin.*). Next.js only rewrites the path here — it is
 * never the source of truth for tenant validity, Laravel's TenantResolver
 * is (Tech Spec §4.1). This middleware just picks which route-group tree
 * to render for a given hostname.
 */
const ROOT_DOMAIN = "tokospace.com";
const ROOT_DOMAIN_DEV = "localhost";

export function middleware(request: NextRequest) {
  const hostname = request.headers.get("host") ?? "";
  const host = hostname.split(":")[0];
  const { pathname } = request.nextUrl;

  const rootDomain = host.endsWith(ROOT_DOMAIN_DEV)
    ? ROOT_DOMAIN_DEV
    : ROOT_DOMAIN;

  if (host === rootDomain || host === `www.${rootDomain}`) {
    return NextResponse.next();
  }

  if (host === `app.${rootDomain}`) {
    return NextResponse.rewrite(
      new URL(`/dashboard${pathname}`, request.url),
    );
  }

  if (host === `admin.${rootDomain}`) {
    return NextResponse.rewrite(new URL(`/admin${pathname}`, request.url));
  }

  const tenant = host.replace(`.${rootDomain}`, "");
  return NextResponse.rewrite(
    new URL(`/s/${tenant}${pathname}`, request.url),
  );
}

export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico).*)"],
};
