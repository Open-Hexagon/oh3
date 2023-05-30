uniform vec4 outline_color;
uniform vec4 text_color;

vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    vec4 pixel = Texel(texture, texture_coords);
    return (outline_color * pixel.r + text_color * pixel.b) * pixel.a;
}
