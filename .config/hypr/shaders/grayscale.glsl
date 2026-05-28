#version 320 es
precision mediump float;

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 c = texture(tex, v_texcoord);
    float gray = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    fragColor = vec4(vec3(gray), c.a);
}

