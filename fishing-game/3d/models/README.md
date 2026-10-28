# Modele z Blendera

Eksport: File → Export → glTF 2.0, format **glTF Binary (.glb)**. Wrzuć pliki tutaj:

| Plik | Co podmienia | Wskazówki |
|---|---|---|
| `bridge.glb` | czerwony most | środek mostu w (0,0,0), most idzie wzdłuż osi Z (w Blenderze oś Y), ok. 32 m długości |
| `sakura.glb` | każdą wiśnię | pień zaczyna się w (0,0,0), wysokość ok. 6 m |
| `fish.glb` | wszystkie ryby | głowa w stronę +X, rozmiar dowolny (gra sama skaluje) |

Jeśli pliku nie ma, gra używa wbudowanych kształtów.

## Wędka i spławik

| Plik | Wskazówki |
|---|---|
| `rod.glb` | dolny koniec (rękojeść) w (0,0,0), wędka pionowo do góry (w Blenderze oś Z). Dodaj Empty o nazwie **`tip`** na szczycie, bo stamtąd wychodzi żyłka. Bez niego gra użyje czubka modelu. Długość dowolna, gra skaluje do 3,2 m. |
| `bobber.glb` | punkt (0,0,0) na linii wody, czyli tam, gdzie spławik się zanurza. Dodaj Empty o nazwie **`line`** tam, gdzie przywiązana jest żyłka. Rozmiar dowolny, gra skaluje do ok. 0,6 m. |

Spławik sam pływa, kołysze się i nurkuje przy braniu, a wędka ugina się przy rzucie i holu. Animacje robi gra, więc w Blenderze wystarczy sam model.
