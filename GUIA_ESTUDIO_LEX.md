# Guía de estudio: Lex/Flex y `lexico_equipo_11_scanner.l`

Guía orientada al analizador léxico del proyecto (`lexico_equipo_11_scanner.l`). Sirve para repasar Flex y para enlazar cada bloque del archivo con ideas de compiladores.

---

## 1. Qué es un archivo `.l` (Lex/Flex)

Flex genera un **analizador léxico** en C: lee texto y lo parte en **tokens** según **patrones (expresiones regulares)**.

Un archivo típico tiene **tres bloques** separados por `%%`:

| Bloque | En tu archivo | Rol |
|--------|----------------|-----|
| **Declaraciones** | Líneas 1–52 (`%{` … `%}`) y 54–68 | Código C copiado al generador + **macros** de patrones |
| **Reglas** | 70–141 | Si la entrada coincide con X, ejecuta este código |
| **Código de usuario** | 143–242 | Funciones C y `main` |

**Idea central:** *patrón → acción*; el motor elige la coincidencia adecuada y ejecuta la acción asociada.

---

## 2. Bloque de declaraciones: C + macros

### C entre `%{` y `%}`

Ahí defines lo que el scanner “conoce” como programa:

- **Constantes de token** (`TOKEN_IDENTIFIER`, `TOKEN_INTEGER`, …): números que luego podría usar un parser.
- **Estructuras y tablas** (`SymbolEntry`, `id_table`, …): memoria para **lexemas** repetidos.
- **Variables de estado** (`line_no`, contadores).
- **`static` y prototipos**: encapsulan helpers solo visibles en el `.c` generado.

**Concepto:** todo lo que pongas entre `%{` y `%}` va al principio del archivo C que genera Flex.

### Macros de regex (después del primer `%}`)

Patrones con nombre para no repetir regex largos. Ejemplos del archivo:

- `LETTER`, `DIGIT` — alfabetos básicos.
- `ID` — identificador: letra o `_`, seguido de letras, dígitos o `_`.
- `INT`, `FLOAT` — literales numéricos.
- `STRING` — comillas simples o dobles, sin salto de línea dentro.
- `WS_COUNT` — `^[ \t]+`: espacios/tabs **al inicio de línea** (indentación).
- `WHITESPACE`, `NEWLINE`, `OPERATOR`, `DELIMITER`, `COMMENT`, etc.

En las reglas se usa `{NOMBRE}` y Flex expande la definición.

**Ejercicio:** para cada macro, escribe en prosa qué texto acepta y 2 ejemplos que **no** acepte.

---

## 3. Bloque de reglas: cómo piensa Flex

Cada regla tiene la forma: **patrón** `{ código C }`.

### Variables imprescindibles

| Símbolo | Significado |
|---------|-------------|
| `yytext` | Puntero al texto que **coincidió** con el patrón (lexema actual) |
| `yyleng` | Longitud de esa coincidencia |
| `yylex()` | Ejecuta el scanner hasta EOF (llama reglas una tras otra) |
| `yyin` | `FILE*` de entrada (por defecto `stdin`) |

### Cómo elige Flex qué regla aplicar

1. **Coincidencia más larga** (“longest match”) gana.
2. Si dos reglas empatan en longitud, **gana la que aparece primero** en el archivo.

Por eso los patrones **más específicos** (comentarios, floats, strings, errores de string) van **antes** que reglas genéricas como `{ID}` o el **`.`** final.

### La regla `.` (punto)

Coincide con **un solo carácter** que no encajó en ninguna regla anterior. En tu scanner es la **red de seguridad** para errores léxicos (símbolo no reconocido).

---

## 4. Recorrido por el diseño de reglas (orden lógico)

1. **`{COMMENT}`** — `#` hasta fin de línea; emite token de comentario.
2. **`{FLOAT}` / `{INT}`** — números; guardan lexema en tabla y emiten token **con índice** (`emit_token_ref`).
3. **`{STRING}`** — cadena con comillas balanceadas en una línea.
4. **`{STRING_UNCLOSED_LINE}` / `{STRING_UNCLOSED_EOF}`** — errores: comilla abierta y salto de línea o fin de archivo.
5. **`{ID}`** — si coincide con palabra reservada → `KEYWORD`; si no → identificador en tabla.
6. **`{OPERATOR}` / `{DELIMITER}`** — tokens simples sin tabla.
7. **`{WS_COUNT}`** — indentación al inicio de línea → token `WS_COUNT`.
8. **`{WHITESPACE}`** — espacios/tabs en medio de línea: acción vacía → **se descartan**.
9. **`{NEWLINE}`** — actualiza `line_no` y emite `NEW_LINE`.
10. **`.`** — carácter ilegal; mensaje a `stderr`.

**Ejercicio:** para la entrada `"a` seguida de `\n`, qué regla aplica y por qué se incrementa `line_no` en el caso de cadena sin cerrar con salto de línea.

---

## 5. Tablas de símbolos y emisión de tokens

- **`add_to_table`**: si el lexema ya existe, devuelve el **mismo índice**; si no, lo inserta (con límite `MAX_SYMBOLS`).
- **`emit_token_simple`**: salida `<id> NOMBRE lexeme`.
- **`emit_token_ref`**: salida `<id,índice> NOMBRE lexeme` para enlazar con la tabla.

Al final, **`print_symbol_tables`** imprime las tablas de identificadores, enteros, floats y strings.

En teoría de compiladores: versión didáctica de **literales en tablas** + **identificadores** con atributo (índice).

---

## 6. Palabras reservadas

La función **`is_keyword`** compara el lexema con un arreglo estático de cadenas (`strcmp`). No se detectan keywords con una regla aparte: **todo pasa por el mismo patrón `{ID}`** y luego se clasifica en C.

---

## 7. `yywrap` y `main`

- **`yywrap()`** devuelve `1` → indica que no hay más entrada; `yylex` termina. Es habitual que el enlazador lo exija.
- **`main`**: si hay argumento, abre el archivo y asigna **`yyin`**; llama **`yylex()`**; imprime tablas; cierra el archivo si no es `stdin`.

---

## 8. Plan de estudio práctico

1. Dibuja el flujo: entrada → `yylex` → regla → `yytext` → `printf` / `stderr`.
2. Lista cada macro `{...}` con 3 ejemplos válidos y 2 inválidos.
3. Piensa en ambigüedades: `1e2` (float vs int), `and` (keyword vs id), espacios al inicio vs en medio de línea (`WS_COUNT` vs `WHITESPACE`).
4. Cuenta las palabras en `keywords` y entiende por qué es tabla + `strcmp` y no un patrón regex por palabra.
5. Compila y prueba con `ejemplo_*.tri` y `errores_lexicos.tri`.

### Compilar (referencia)

```bash
flex -o lex.yy.c lexico_equipo_11_scanner.l && cc -o scanner lex.yy.c -lfl
```

En algunos sistemas la biblioteca de Flex se enlaza con `-ll` en lugar de `-lfl`.

---

## 9. Mapa rápido: teoría ↔ tu código

| Concepto | Dónde aparece |
|----------|----------------|
| Lexema | `yytext` |
| Patrón / clase léxica | Macros `ID`, `FLOAT`, `STRING`, … |
| Token (tipo + atributo) | `token_id` y opcionalmente índice en `emit_token_ref` |
| Error léxico | `STRING_UNCLOSED_*`, regla `.` |
| Tabla de símbolos (simplificada) | `add_to_table` + arrays estáticos |

---

## 10. Archivo fuente de referencia

Toda la guía se basa en:

`lexico_equipo_11_scanner.l`

Si actualizas patrones o tokens, conviene revisar también esta guía para mantenerla alineada.
