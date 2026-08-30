// Liefert die aktuell getragenen Item-IDs eines Spielers serverseitig, damit der clientseitige
// "Gear synchronisieren"-Knopf auf der Seite keinen Drittanbieter-CORS-Proxy mehr braucht
// (corsproxy.io hat sein anonymes URL-Format 2026-08 abgeschafft, kostenlose Alternativen wie
// allorigins.win/thingproxy sind unzuverlaessig). Primaerquelle ist Blizzards eigene,
// oeffentliche Classic-Armory-Seite (kein OAuth noetig, s. 2-fetch-gear.ps1 fuer Details zum
// Format); classic-armory.org bleibt als Fallback.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const REGION = "eu";
const REALM = "thunderstrike";
const LOCALE = "en-gb";

async function fetchViaBlizzard(name: string): Promise<number[] | null> {
  const encoded = encodeURIComponent(name);
  const url = `https://worldofwarcraft.blizzard.com/${LOCALE}/classicann/${REGION}/armory/character/${REALM}/${encoded}`;
  let html: string;
  try {
    const resp = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0 (Lootprio-Armory-Edge-Function)" },
    });
    if (!resp.ok) return null;
    html = await resp.text();
  } catch {
    return null;
  }

  const match = html.match(/characterProfileInitialState = (\{.*?\});\s*<\/script>/s);
  if (!match) return null;

  let data: any;
  try {
    data = JSON.parse(match[1]);
  } catch {
    return null;
  }
  const gear = data?.character?.gear;
  if (!gear) return null;

  const ids: number[] = [];
  for (const slot of Object.values(gear) as any[]) {
    if (slot?.id > 0) ids.push(Number(slot.id));
  }
  return ids.length > 0 ? ids : null;
}

async function fetchViaClassicArmory(name: string): Promise<number[] | null> {
  try {
    const resp = await fetch("https://classic-armory.org/api/v1/character/equipment", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ region: REGION, realm: REALM, name, flavor: "tbc-anniversary" }),
    });
    if (!resp.ok) return null;
    const data = await resp.json();
    if (!data?.equipment) return null;
    const ids = data.equipment
      .filter((e: any) => e?.item?.id > 0)
      .map((e: any) => Number(e.item.id));
    return ids.length > 0 ? ids : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    // Authentifizierung pruefen (gleiche Gate wie trigger-sync, aber ohne den
    // @supabase/supabase-js-Import - der laesst sich beim Editor-Deploy nicht bundeln,
    // "Cannot import from github.com:443". Direkter REST-Call gegen Supabase Auth stattdessen.
    const authHeader = req.headers.get("Authorization") ?? "";
    const userResp = await fetch(`${Deno.env.get("SUPABASE_URL")}/auth/v1/user`, {
      headers: {
        Authorization: authHeader,
        apikey: Deno.env.get("SUPABASE_ANON_KEY")!,
      },
    });
    if (!userResp.ok) {
      return new Response(JSON.stringify({ error: "Nicht angemeldet." }), {
        status: 401,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const { name } = await req.json();
    if (!name || typeof name !== "string") {
      return new Response(JSON.stringify({ error: "Kein Spielername uebergeben." }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    let ids = await fetchViaBlizzard(name);
    let source = "blizzard";
    if (!ids) {
      ids = await fetchViaClassicArmory(name);
      source = "classic-armory";
    }
    if (!ids) {
      return new Response(JSON.stringify({ error: `Kein Gear fuer '${name}' gefunden.` }), {
        status: 502,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ ids, source }), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
