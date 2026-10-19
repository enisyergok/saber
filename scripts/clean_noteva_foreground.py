"""Remove isolated transparent-foreground artifacts from the Noteva mark."""

from collections import deque
from pathlib import Path

from PIL import Image


SOURCE = Path("assets/icon/noteva-foreground-source.png")


def main() -> None:
    image = Image.open(SOURCE).convert("RGBA")
    pixels = image.load()
    width, height = image.size
    active = bytearray(width * height)
    for y in range(height):
        for x in range(width):
            active[y * width + x] = pixels[x, y][3] >= 96

    largest = bytearray(width * height)
    largest_size = 0
    for start, is_active in enumerate(active):
        if not is_active:
            continue
        active[start] = 0
        queue = deque([start])
        component = []
        while queue:
            index = queue.popleft()
            component.append(index)
            x = index % width
            y = index // width
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < width and 0 <= ny < height:
                    neighbor = ny * width + nx
                    if active[neighbor]:
                        active[neighbor] = 0
                        queue.append(neighbor)
        if len(component) > largest_size:
            largest_size = len(component)
            largest = bytearray(width * height)
            for index in component:
                largest[index] = 255

    for y in range(height):
        for x in range(width):
            r, g, b, _ = pixels[x, y]
            pixels[x, y] = (r, g, b, largest[y * width + x])
    image.save(SOURCE)
    print(f"Kept the main Noteva foreground component ({largest_size} pixels).")


if __name__ == "__main__":
    main()
