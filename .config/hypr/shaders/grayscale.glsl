#version 320 es
precision mediump float;

in  vec2  v_texcoord;
out vec4  fragColor;

uniform sampler2D tex;

void main() {
    vec4  c    = texture(tex, v_texcoord);
    float luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));

    // warm
    vec3  saturated = mix(vec3(luma), c.rgb, 1.6);
    vec3  yellow    = vec3(1.0, 0.90, 0.6);
    vec3  tinted    = saturated * yellow;
    fragColor       = vec4(tinted * 0.62, c.a);
}
