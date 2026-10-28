# Sakura River

Prosta gra wędkarska w jednym pliku (`index.html`, czysty JS + canvas, bez bibliotek).
Widok jak w akwarium: przekrój rzeki, czerwony japoński most, kwitnące wiśnie, spadające płatki, rybak z wędką na brzegu.

## Sterowanie
1. Przytrzymaj palec (albo spację), żeby naładować siłę rzutu, i puść, żeby zarzucić.
2. Ryby podpływają do haczyka. Kiedy spławik zanurkuje (napis „BRANIE!”), szybko dotknij.
3. Hol: trzymaj, żeby zwijać. Puść, kiedy pasek napięcia robi się czerwony, bo inaczej linka pęknie.
   Jeśli puszczasz za długo, ryba się zerwie.

Gatunki: płotka, okoń, karp, pstrąg, szczupak, koi. Im rzadsza ryba, tym więcej punktów i tym mocniej walczy.
Rekord zapisuje się w localStorage.

## Android
- Najszybciej: zapakować folder w Capacitor (`npx cap init`, `npx cap add android`, `webDir` = ten folder)
  albo wyświetlić `index.html` w WebView.
- Godot 4: nie da się uruchomić tego kodu JS w Godocie, ale logika (stany `idle/charging/flying/waiting/bite/reeling`)
  przenosi się 1:1 do GDScript. Model 3D z Blendera (.glb) można podpiąć jako rybaka/most.
