//
//  RealisticShaders.swift
//  NeedleWorksKit
//

/// The Metal shaders for the Realistic style, compiled when first used.
///
/// Each stitch is drawn as two quads: a soft shadow, then the thread. The
/// fragment shader models the thread itself: slightly flattened and round
/// across its width, sinking into the fabric at its ends, two plies twisted
/// at a shallow angle, and fibres along them that reflect light along their
/// length (Kajiya-Kay), with glints that vary along each fibre. Each stitch
/// also wanders and varies in thickness a little, and its fibres end raggedly.
let realisticShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct StitchData {
    float4 ab;      // start.xy, end.xy in design units (y down)
    float4 color;   // linear rgb
    float4 params;  // width, seed, tone, twist phase
};

struct Uniforms {
    float2 origin;  // design units at the top left of the image
    float2 size;    // design units covered by the image
    float  pixelsPerUnit;
};

struct VOut {
    float4 position [[position]];
    float2 local;           // along (from start), across (design units)
    float  length;
    float  radius;
    float2 dir;             // stitch direction on screen
    float4 color;
    float4 params;
    uint   shadow;
};

// Two quads per stitch: its shadow first, then the thread, so each stitch's
// shadow falls on the stitches sewn before it.
vertex VOut stitchVertex(uint vid [[vertex_id]], uint iid [[instance_id]],
                         const device StitchData *stitches [[buffer(0)]],
                         constant Uniforms &u [[buffer(1)]]) {
    StitchData s = stitches[iid];
    float2 a = s.ab.xy, b = s.ab.zw;
    float2 d = b - a;
    float len = max(length(d), 0.5);
    float2 dir = d / len;
    float2 across = float2(-dir.y, dir.x);
    float r = s.params.x * 0.5;
    uint shadow = vid < 6 ? 1 : 0;
    uint corner = vid % 6;
    // two triangles: (0,1,2) (2,1,3)
    const uint ids[6] = {0, 1, 2, 2, 1, 3};
    uint c = ids[corner];
    float pad = r * 1.6;
    float alongPos = (c & 1) ? len + pad : -pad;
    float acrossPos = (c & 2) ? pad : -pad;
    float2 p = a + dir * alongPos + across * acrossPos;
    if (shadow) { p += float2(0.7, 0.7); }
    float2 ndc = (p - u.origin) / u.size * 2.0 - 1.0;
    VOut o;
    o.position = float4(ndc.x, -ndc.y, 0, 1);
    o.local = float2(alongPos, acrossPos);
    o.length = len;
    o.radius = r;
    o.dir = dir;
    o.color = s.color;
    o.params = s.params;
    o.shadow = shadow;
    return o;
}

static float hash(float3 p) {
    p = fract(p * float3(443.897, 441.423, 437.195));
    p += dot(p, p.yzx + 19.19);
    return fract((p.x + p.y) * p.z);
}

fragment float4 stitchFragment(VOut in [[stage_in]]) {
    float L = in.length, r = in.radius;
    float u = in.local.x, w = in.local.y;

    float seed = in.params.y, tone = in.params.z, phase = in.params.w;
    float h1 = hash(float3(seed, 1.3, 0.7)), h2 = hash(float3(seed, 5.1, 2.9)), h3 = hash(float3(seed, 8.7, 4.4));
    float t = saturate(u / max(L, 1.0));

    // No two stitches lie alike: each one wanders a little across its path
    // and varies in thickness along it, where it is pressed or pulled
    float wobble = r * 0.1 * (h1 - 0.5) * 2.0 * sin(t * M_PI_F)
                 + r * 0.04 * sin(t * M_PI_F * (2.0 + 3.0 * h2) + h3 * 6.283);
    float wl = w - wobble;
    float rr = r * (0.94 + 0.1 * h3 + 0.05 * sin(t * M_PI_F * (1.0 + 2.0 * h1) + h2 * 6.283));

    // Ragged ends: the thread sinks into the fabric with blunt ends, and the
    // fibres across it end at slightly different places
    float band = floor(saturate(wl / rr * 0.5 + 0.5) * 14.0);
    float startAt = (hash(float3(seed, band, 3.3)) - 0.5) * r * 0.35;
    float endAt = L + (hash(float3(seed, band, 6.6)) - 0.5) * r * 0.35;
    float cu = clamp(u, startAt, max(endAt, startAt));
    float2 q = float2((u - cu) / 0.45, wl);
    float dist = length(q);
    float aa = max(fwidth(dist), 1e-4);

    if (in.shadow) {
        float a = 0.16 * (1.0 - smoothstep(rr - aa, rr + 0.8, dist));
        return float4(0, 0, 0, a);
    }

    float coverage = 1.0 - smoothstep(rr - aa, rr, dist);
    if (coverage <= 0.0) { discard_fragment(); }

    // The thread, slightly flattened where it lies on the fabric: across
    // position s gives the surface normal.
    float s = clamp(wl / rr, -0.999, 0.999);
    float theta = asin(s);
    float3 n = normalize(float3(0.0, s, sqrt(1.0 - s * s) * 0.75));

    // Where the thread goes into the fabric, its surface turns downward.
    float endIn = 1.0 - saturate(u / (r * 1.8));
    float endOut = saturate((u - (L - r * 1.8)) / (r * 1.8));
    n.x += -endIn * 1.2 + endOut * 1.2;

    // Long satin stitches arch over a raised column, padded by underlay, so
    // the middle of a stitch catches the light and both ends fall into shadow
    float arch = 0.9 * saturate((L - 8.0) / 25.0);
    n.x += arch * (2.0 * u / L - 1.0);
    n = normalize(n);
    float archShade = 1.0 - 0.45 * arch * pow(abs(2.0 * u / L - 1.0), 2.0);
    float endShade = 1.0 - 0.55 * max(endIn, endOut);

    // Two twisted plies: plyPos counts ply bands along the helix.
    // Machine thread's twist is shallow: the plies wind about 15 degrees from
    // the thread's axis, so its fibres run nearly lengthwise. Two plies make
    // a turn of the helix hold two ply bands.
    float run = r * tan(75.0 * M_PI_F / 180.0);  // along the thread per radian around it
    float pitch = M_PI_F * run;
    float plyPos = (u - run * (theta + M_PI_2_F) - phase) / pitch;
    float ply = floor(plyPos);
    float f = plyPos - ply;              // 0..1 across one ply

    // Fade the plies' detail out as they shrink toward a pixel, so small
    // zooms show their average instead of shimmering patterns
    float detail = 1.0 - smoothstep(0.25, 0.6, fwidth(plyPos));

    // The ply's helix direction on the surface, and the direction across it
    float3 helix = normalize(float3(run, r * cos(theta), -r * sin(theta)));
    float3 plyAcross = normalize(cross(n, helix));

    // Each ply is a rounded bump; its normal tilts away from the ply's middle
    float bump = (f - 0.5) * 2.0;
    float3 pn = normalize(n + plyAcross * bump * 0.1 * detail);

    // Fibers run along each ply, each with its own gloss and slight tilt
    float fibers = 14.0;
    float fiber = floor(f * fibers);
    float fh = hash(float3(ply, fiber, seed));
    float fh2 = hash(float3(fiber, ply * 1.7, seed + 3.1));
    float3 tangent = normalize(helix + (plyAcross * (fh2 - 0.5) * 0.35 + pn * (fh - 0.5) * 0.25) * detail);
    float gloss = mix(1.0, 0.6 + 0.8 * fh, detail);

    // Along each fibre the glints rise and fade smoothly, at random and
    // mostly dim, as in photos of real machine thread
    float alongPly = (u * run + r * r * theta) / sqrt(run * run + r * r) / (r * 1.6) + fh * 3.0;
    float segment = floor(alongPly);
    float k = smoothstep(0.0, 1.0, alongPly - segment);
    float dash = mix(hash(float3(ply * 3.1 + fiber, segment, seed + 11.0)),
                     hash(float3(ply * 3.1 + fiber, segment + 1.0, seed + 11.0)), k);
    float glint = mix(1.0, 0.3 + 2.0 * dash * dash * dash, detail);

    // Light from the top left (y down) and above, in the stitch's frame
    float3 Ls = normalize(float3(-1.0, -1.0, 1.4));
    float2 across2 = float2(-in.dir.y, in.dir.x);
    float3 Lt = normalize(float3(dot(Ls.xy, in.dir), dot(Ls.xy, across2), Ls.z));
    float3 V = float3(0, 0, 1);
    float3 H = normalize(Lt + V);

    // Diffuse light from the round thread and its plies together
    float3 dn = normalize(n + pn);
    float diffuse = saturate(dot(dn, Lt) * 0.75 + 0.25);

    // Fibers reflect along their length (Kajiya-Kay), but only where the
    // thread's surface faces the light, so the glints gather in a band along
    // the thread and it reads as round
    float th = dot(tangent, H);
    float sinTH = sqrt(max(0.0, 1.0 - th * th));
    float facing = pow(saturate(dot(n, H)), 4.0) * mix(1.0, pow(saturate(dot(pn, H)), 6.0), detail);
    float spec = pow(sinTH, 30.0) * gloss * glint * facing * 1.6;
    float sheen = pow(sinTH, 8.0) * 0.35 * mix(0.5, 1.0, facing);

    // Grooves between the round plies, and shadow on the thread's sides,
    // where it curves away and its neighbours block the light
    float groove = mix(0.85, smoothstep(0.0, 0.45, f) * smoothstep(0.0, 0.45, 1.0 - f), detail);
    float edge = mix(0.35, 1.0, smoothstep(0.98, 0.6, abs(s)));
    float occlusion = mix(0.96, 1.0, groove) * edge * endShade * archShade;
    float ends = 1.0 - max(endIn, endOut);

    float3 base = in.color.rgb * (1.0 + tone);
    float3 color = base * (0.3 + 0.7 * diffuse) * occlusion;
    float3 specColor = mix(float3(1.0), base / max(max(base.r, base.g), max(base.b, 1e-3)), 0.15);
    float3 sheenColor = mix(base, specColor * 0.35, 0.5);
    color += (specColor * spec * 0.65 + sheenColor * sheen) * mix(0.7, 1.0, groove) * ends * edge;
    return float4(color * coverage, coverage);
}
"""
