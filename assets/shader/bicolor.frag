uniform vec4 red;
uniform vec4 blue;

vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    vec4 pixel = Texel(texture, texture_coords);
    return (red * pixel.r + blue * pixel.b) * pixel.a;
}
