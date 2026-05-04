# Analizador lexico

Scanner con `lex` / `flex`. Los fuentes (`.l`, `.tri`) están en la raíz de este repo.

## Para qué sirve `.gitignore`

Le dice a **Git** qué archivos **no** subir al repositorio: generados (como `lex.yy.c`), binarios del compilador y basura del sistema (`.DS_Store`). Así el repo solo lleva lo que importa para compilar de nuevo en cualquier máquina.

## Cómo correrlo

1. Genera el C desde el archivo Lex:

```bash
lex lexico_equipo_11_scanner.l
```

2. Compila el ejecutable:

```bash
cc lex.yy.c -o lexico_equipo_11_scanner -ll
```

3. Ejecuta con un archivo de prueba:

```bash
./lexico_equipo_11_scanner ejemplo_1.tri
```

## Ejemplos rápidos

```bash
./lexico_equipo_11_scanner ejemplo_1.tri
./lexico_equipo_11_scanner ejemplo_2.tri
./lexico_equipo_11_scanner ejemplo_3.tri
./lexico_equipo_11_scanner ejemplo_4.tri
./lexico_equipo_11_scanner errores_lexicos.tri
```
