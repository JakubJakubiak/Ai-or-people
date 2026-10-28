# Modele z Blendera

`tree.glb` i `bridge.glb` są skopiowane z repo `JakubJakubiak/sakura-river` (źródło: `models/sakura-models.blend`).
`fish.glb`, `rod.glb`, `bobber.glb` to wyeksportowane modele z kodu gry (`exportModels()` w konsoli), do edycji w Blenderze.

Eksport: File → Export → glTF 2.0, format **glTF Binary (.glb)**. Wrzuć pliki tutaj:

| Plik | Co podmienia | Wskazówki |
|---|---|---|
| `bridge.glb` | most | z projektu **sakura-river** (`models/bridge.glb`), części nazwane materiałami (`red`, `wood`, `stone`...) |
| `tree.glb` | wiśnie | z projektu **sakura-river** (`models/tree.glb`): części `Tree_0..2_bark/blossom/crown`, kwiaty rysuje shader z Sakura River |
| `fish.glb` | wszystkie ryby | głowa w stronę +X, rozmiar dowolny (gra sama skaluje) |

Jeśli pliku nie ma, gra używa wbudowanych kształtów.

## Wędka i spławik

| Plik | Wskazówki |
|---|---|
| `rod.glb` | dolny koniec (rękojeść) w (0,0,0), wędka pionowo do góry (w Blenderze oś Z). Dodaj Empty o nazwie **`tip`** na szczycie, bo stamtąd wychodzi żyłka. Bez niego gra użyje czubka modelu. Długość dowolna, gra skaluje do 3,2 m. |
| `bobber.glb` | punkt (0,0,0) na linii wody, czyli tam, gdzie spławik się zanurza. Dodaj Empty o nazwie **`line`** tam, gdzie przywiązana jest żyłka. Rozmiar dowolny, gra skaluje do ok. 0,6 m. |

Spławik sam pływa, kołysze się i nurkuje przy braniu, a wędka ugina się przy rzucie i holu. Animacje robi gra, więc w Blenderze wystarczy sam model.
