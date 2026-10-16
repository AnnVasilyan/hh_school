-- ============================================================
-- Домашнее задание к лекции «SQL. Введение»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Васильева Анна Олеговна
-- ============================================================
-- Формат: задания по порядку, каждое начинается с комментария
-- с номером; под каждым запросом — вывод (2–3 предложения).
-- Запрос без вывода не засчитывается.
-- ============================================================

SET search_path TO hh_school;


-- ============================================================
-- БЛОК А. Разминка: термины и структура (текстом)
-- ============================================================

-- ЗАДАНИЕ А1
-- 1. Категория и конкретный тип колонок:
--    vacancies.salary_from        — категория: числовой           тип: INT 
--    vacancies.vacancy_name       — категория: строковый          тип: VARCHAR 
--    vacancies.published_at       — категория: дата и время       тип: TIMESTAMP
--    employers.is_accredited_it   — категория: логический         тип: BOOLEAN
--    responses.created_at         — категория: дата и время       тип: TIMESTAMP
--
-- 2. Первичные ключи таблиц:
--    areas: area_id
--    employers: employer_id
--    vacancies: vacancy_id
--    vacancy_details: vacancy_id (чем особенный: это одновременно первичный и внешний ключ)
--    responses: response_id
--
-- 3. Почему vacancy_name не может быть первичным ключом:
--    первичный ключ обязан быть уникальным, а названия вакансий повторяются.
--    Запрос для подтверждения числом:

-- запрос:
SELECT vacancy_name,
       count(*) AS cnt
FROM vacancies
GROUP BY vacancy_name
ORDER BY cnt DESC, vacancy_name
LIMIT 1;

-- Вывод: самое частое название «Стажёр: аналитик данных», оно встречается 6 раз . Значит,
-- первичным ключом оно быть не может.
--
-- 4. Что произойдёт при записи строки «по договорённости» в salary_from:
--    колонка имеет тип INT, поэтому СУБД отклонит запись с ошибкой. Так как в колонке лежат только числа,
--    и операции над числами работают корректно. Если бы был текст, 
--    расчёт зарплат давал бы неверный результат. Отсутствие зарплаты записывается как NULL, 
--    тогда расчеты не сломаются.

-- ============================================================
-- БЛОК Б. Первые запросы: SELECT, WHERE, ORDER BY
-- ============================================================

-- ЗАДАНИЕ Б1
-- Запрос: experience
SELECT DISTINCT experience
FROM vacancies
ORDER BY experience;

-- Запрос: employment
SELECT DISTINCT employment
FROM vacancies
ORDER BY employment;

-- Запрос: professional_role
SELECT DISTINCT professional_role
FROM vacancies
ORDER BY professional_role;

-- Вывод: в experience 3 значения (Нет опыта; От 1 года до 3 лет; От 3 до 6 лет),
-- в employment тоже 3 (Полная занятость; Стажировка; Частичная занятость), в
-- professional_role — 5 (Аналитик данных, Дата-инженер, Продуктовый аналитик, Разработчик,
-- Тестировщик). Проблем нет: значения NULL нет, 
-- одни и те же значения в разных написаниях (регистр, лишние пробелы) не встречаются, 
-- поэтому по этим колонкам можно фильтровать.


-- ЗАДАНИЕ Б2
-- Запрос 1: стажировки в Москве без опыта, вакансия открыта
-- area_id = 1 — Москва; closed_at IS NULL — вакансия ещё открыта;
SELECT vacancy_id, vacancy_name, salary_from, published_at
FROM vacancies
WHERE employment = 'Стажировка'
  AND experience = 'Нет опыта'
  AND area_id = 1
  AND closed_at IS NULL
ORDER BY published_at DESC;

-- Запрос 2: топ-10 вакансий по salary_from
SELECT vacancy_name, professional_role, salary_from
FROM vacancies
ORDER BY salary_from DESC NULLS LAST
LIMIT 10;

-- Вывод: 
-- Первый запрос нашёл 8 открытых стажировок в Москве без опыта. Если убрать условие
-- про Москву, их станет 10, то есть на Москву приходится 80% таких вакансий. Самая свежая
-- опубликована 3 июня, а четыре опубликованы до апреля и всё ещё числятся
-- открытыми, поэтому актуальность стоит проверять. 
-- Во втором запросе без NULLS LAST часть из "топ-10" заняли бы вакансии без зарплаты и 
-- Senior-позиций, и ни одной стажировки.


-- ЗАДАНИЕ Б3
-- Ловушка 1. NULL — выполнить и объяснить результат
SELECT count(*) FROM vacancies WHERE closed_at = NULL;
SELECT count(*) FROM vacancies WHERE closed_at IS NULL;

-- Ловушка 2. AND / OR — выполнить и объяснить результат
SELECT count(*) FROM vacancies
WHERE area_id = 1 OR area_id = 2 AND experience = 'Нет опыта';

SELECT count(*) FROM vacancies
WHERE (area_id = 1 OR area_id = 2) AND experience = 'Нет опыта';

-- Вывод: первый запрос вернул 0, второй - 33. Сравнение = NULL не истинно и не ложно, а
-- неизвестно. Поэтому ошибки нет, а результат выглядит правдоподобно 
-- "открытых вакансий нет", и именно поэтому он опаснее ошибки.
-- NULL в closed_at означает, что вакансия ещё открыта. Таких вакансий 33.

-- Первый запрос: area_id = 1 OR (area_id = 2 AND experience = 'Нет опыта') — 26 вакансий.
-- Москвы с любым опытом плюс Питер без опыта.
-- На вопрос "Москва или Санкт-Петербург, без опыта" отвечает второй запрос со скобками: 20 вакансий.


-- ============================================================
-- БЛОК В. Агрегации и метрики
-- ============================================================

-- ЗАДАНИЕ В1
-- Запрос 1: счётчики (строки, зарплата указана, направления, работодатели)
SELECT count(*) AS total_rows,  
       count(salary_from) AS with_salary,
       count(DISTINCT professional_role) AS roles_cnt,
       count(DISTINCT employer_id) AS employers_cnt
FROM vacancies;

-- Запрос 2: доля активных вакансий (без JOIN)
SELECT count(*) FILTER (WHERE closed_at IS NULL)     AS open_cnt,
       count(*) FILTER (WHERE closed_at IS NOT NULL) AS closed_cnt,
       round(100.0 * count(*) FILTER (WHERE closed_at IS NULL) / nullif(count(*), 0), 1) AS open_pct
FROM vacancies;

-- Вывод: count(*) = 52 считает все строки, то есть все вакансии; count(salary_from) = 44
-- считает только непустые значения — у 8 вакансий зарплата не указана и они пропущены;
-- count(DISTINCT professional_role) = 5 — это не число строк, а число различных направлений
-- среди этих 52 вакансий (а различных работодателей — 12).
-- Ответ руководителю: сейчас открыто 33 из 52 вакансий — 63,5%, остальные 19 уже закрыты.


-- ЗАДАНИЕ В2
-- Запрос 1: направления — вакансии, работодатели, средняя зарплата
SELECT professional_role,
       count(*)                    AS vacancies_cnt,
       count(DISTINCT employer_id) AS employers_cnt,
       round(avg(salary_from))     AS avg_salary_from
FROM vacancies
GROUP BY professional_role
ORDER BY vacancies_cnt DESC;

-- Запрос 2: то же, только направления с ≥ 5 открытыми вакансиями (WHERE + HAVING)
SELECT professional_role,
       count(*)                    AS open_vacancies_cnt,
       count(DISTINCT employer_id) AS employers_cnt,
       round(avg(salary_from))     AS avg_salary_from
FROM vacancies
WHERE closed_at IS NULL
GROUP BY professional_role
HAVING count(*) >= 5
ORDER BY open_vacancies_cnt DESC;

-- Вывод: больше половины рынка занимают «Аналитик данных» (16 вакансий) и «Разработчик» (15):
-- вместе 31 из 52, около 60%. Соискатель по одной этой таблице решил бы, что откликаться
-- нужно на аналитиков и разработчиков, но в ней нет откликов (конкуренции) и результата
-- откликов (конверсии), так что вывод был бы необоснованным. WHERE работает до группировки и
-- отбирает строки (только открытые), а количество в группе появляется только после GROUP BY,
-- поэтому условие «не менее пяти» пишется в HAVING; запрос с WHERE count(*) >= 5 завершится
-- ошибкой «aggregate functions are not allowed in WHERE». Во втором запросе «Продуктовый
-- аналитик» выпал: у него открыто всего 4 вакансии.
-- avg(salary_from) отвечает на вопрос «какова средняя нижняя граница зарплаты среди вакансий
-- направления, где она указана» (в базе таких 44 из 52). Он не отвечает, сколько реально
-- заплатят: не учитывает salary_to, вакансии без зарплаты и смешивает стажёров с Senior.


-- ============================================================
-- БЛОК Г. Соединение таблиц
-- ============================================================

-- ЗАДАНИЕ Г1
-- Запрос: топ-5 по salary_from с названием компании и городом (псевдонимы таблиц)
SELECT v.vacancy_name, e.employer_name, a.area_name, v.salary_from
FROM vacancies v
JOIN employers e ON v.employer_id = e.employer_id
JOIN areas a     ON v.area_id = a.area_id
ORDER BY v.salary_from DESC NULLS LAST
LIMIT 5;

-- Вывод: самая высокая нижняя граница — 195 000 у Senior-разработчика в «Северном Коде»
-- (Санкт-Петербург), следом Senior дата-инженер в «УралСофте» (190 000). Если убрать
-- псевдонимы и написать просто area_id, запрос упадёт с ошибкой «column reference "area_id"
-- is ambiguous»: колонка area_id есть сразу в vacancies, employers и areas, и база не знает,
-- какую из них брать; префикс v. или a. снимает неоднозначность.


-- ЗАДАНИЕ Г2
-- Запрос 1: все работодатели, число вакансий и откликов (LEFT JOIN)
SELECT e.employer_name,
       count(DISTINCT v.vacancy_id) AS vacancies_cnt,
       count(r.response_id)         AS responses_cnt
FROM employers e
LEFT JOIN vacancies v ON e.employer_id = v.employer_id
LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
GROUP BY e.employer_id, e.employer_name
ORDER BY responses_cnt DESC;

-- Запрос 2: тот же запрос с INNER JOIN
SELECT e.employer_name,
       count(DISTINCT v.vacancy_id) AS vacancies_cnt,
       count(r.response_id)         AS responses_cnt
FROM employers e
INNER JOIN vacancies v ON e.employer_id = v.employer_id
INNER JOIN responses r ON v.vacancy_id = r.vacancy_id
GROUP BY e.employer_id, e.employer_name
ORDER BY responses_cnt DESC;

-- Вывод: после соединения с responses строка вакансии повторяется столько раз, сколько у неё
-- откликов, поэтому count(*) посчитал бы строки соединения, а не вакансии (у «ТехноБанка» 157
-- вместо 9), и вакансии считаются через count(DISTINCT v.vacancy_id). Первый запрос вернул
-- 12 строк, второй 11: исчез «ГринЭнерго» (1 вакансия, 0 откликов). Это содержательная
-- потеря: именно такие компании HR и хочет увидеть, чтобы спросить, почему нет интереса;
-- кроме того, INNER JOIN тихо занизил число вакансий у других компаний (у «ТехноБанка» 9→8,
-- «СибирьТелеком» 4→1), потому что вакансии без откликов (их 10) выпали из результата.
-- Правило: LEFT JOIN, когда нельзя потерять строки основной таблицы и важен ноль
-- (метрика по всем работодателям или вакансиям); INNER JOIN, когда нужны только связанные
-- записи (например, анализ самих откликов).


-- ============================================================
-- БЛОК Д. Функции и финальный кейс
-- ============================================================

-- ЗАДАНИЕ Д1
-- Запрос: помесячная динамика откликов и конверсия
-- (месяц как дата, условный агрегат, nullif в знаменателе)
SELECT date_trunc('month', created_at)::date AS month,
       count(*)                              AS responses_cnt,
       count(*) FILTER (WHERE status = 'invited') AS invited_cnt,
       round(100.0 * count(*) FILTER (WHERE status = 'invited')
             / nullif(count(*), 0), 1)       AS conversion_pct
FROM responses
GROUP BY 1
ORDER BY 1;

-- Вывод: максимальная конверсия — в июне 2026: 19,5% (23 приглашения на 118 откликов).
-- Объёму июня доверять можно: это второй по величине месяц, и он не похож на январь, где всего
-- 24 отклика и 4 приглашения, а в соседних месяцах с сопоставимым объёмом (апрель — 111,
-- июль — 142) конверсия 13,5% и 12,7%. Но это один месяц из восьми и один сезон, поэтому
-- планировать на нём набор рано. Последний месяц, август, неполный: отклики есть только по
-- 15 августа (41 отклик, 3 приглашения, 7,3%), и одно приглашение там сдвигает конверсию
-- примерно на 2,4 п.п., поэтому его лучше исключить из выводов.


-- ЗАДАНИЕ Д2
-- Запрос: таблица по направлениям (вакансии, отклики, приглашения,
-- откликов на вакансию, конверсия)
-- (LEFT JOIN, чтобы вакансии без откликов попали в знаменатель)
SELECT v.professional_role,
       count(DISTINCT v.vacancy_id)                                  AS vacancies_cnt,
       count(r.response_id)                                          AS responses_cnt,
       count(r.response_id) FILTER (WHERE r.status = 'invited')      AS invited_cnt,
       round(1.0 * count(r.response_id)
             / nullif(count(DISTINCT v.vacancy_id), 0), 1)           AS responses_per_vacancy,
       round(100.0 * count(r.response_id) FILTER (WHERE r.status = 'invited')
             / nullif(count(r.response_id), 0), 1)                   AS conversion_pct
FROM vacancies v
LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
GROUP BY v.professional_role
ORDER BY conversion_pct DESC;

-- Письменные ответы:
-- 1. Совпадает ли направление с наибольшим числом вакансий с направлением
--    с наибольшей конверсией?
--    Нет. Больше всего вакансий у «Аналитика данных» (16), но его конверсия 12,1% — в
--    нижней группе (11,7–12,1%), а наибольшая конверсия у «Тестировщика» — 35,9%.
--
-- 2. Какое направление выбрать и почему (опираясь на два столбца):
--    «Разработчик»: по числу вакансий (15) и по конверсии (17,3%) оно второе, то есть единственное
--    направление в топ-2 по обоим столбцам. Дополнительно оно даёт 24 приглашения и
--    9,3 отклика на вакансию против 19,6 у аналитиков, то есть конкуренция примерно вдвое ниже.
--    «Тестировщик» лидирует по конверсии, но у него всего 7 вакансий и 39 откликов, поэтому
--    он годится как дополнение, а не как основная ставка.
--
-- 3. Оговорка к выводу:
--    конверсия посчитана от всех откликов, а 276 из 628 (44%) откликов ещё в статусах new и
--    viewed и решения по ним нет. Поэтому это доля приглашённых среди всех откликов к моменту
--    выгрузки, а не окончательный шанс получить приглашение, и данные не говорят, подходит ли
--    конкретному кандидату направление.


-- ============================================================
-- БЛОК Е. Со звёздочкой
-- ============================================================

-- ЗАДАНИЕ Е1
-- Исходный запрос (выполнить и посмотреть результат):
-- SELECT v.professional_role,
-- count(*) AS vacancies,
-- sum(v.salary_from) AS total_salary,
-- count(r.response_id) / count(*) AS responses_per_vacancy
-- FROM vacancies v
-- JOIN responses r ON v.vacancy_id = r.vacancy_id
-- WHERE v.closed_at = NULL
-- GROUP BY 1;
--
-- Результат исходного запроса — 0 строк. Если заменить только «= NULL» на IS NULL, остальные
-- ошибки проявятся: у «Аналитика данных» vacancies = 236 (реально открыто 11), total_salary =
-- 13 870 000 (на самом деле 815 000), а responses_per_vacancy = 1 у всех направлений.
--
-- Ошибки (минимум четыре):
-- 1. WHERE v.closed_at = NULL: сравнение с NULL никогда не истинно, поэтому запрос возвращает
--    ноль строк. Нужно IS NULL.
-- 2. JOIN (INNER) с responses отбрасывает вакансии без откликов, а они должны попасть в
--    знаменатель: нужен LEFT JOIN.
-- 3. count(*) считает строки после соединения, то есть отклики, а не вакансии (236 вместо
--    11). Вакансии считаются через count(DISTINCT v.vacancy_id).
-- 4. sum(v.salary_from) после соединения 1:N повторяет зарплату вакансии для каждого её
--    отклика, и сумма завышается (в 17 раз у аналитиков). Сумму нужно считать на уровне
--    вакансий, до соединения с responses.
-- 5. count(r.response_id) / count(*) — целочисленное деление (результат 1), к тому же после
--    INNER JOIN числитель и знаменатель равны. Нужны 1.0 *, nullif в знаменателе и правильный
--    знаменатель (число вакансий, а не строк).
--
-- Исправленный запрос:
WITH resp AS (
    SELECT vacancy_id, count(*) AS cnt
    FROM responses
    GROUP BY vacancy_id
)
SELECT v.professional_role,
       count(DISTINCT v.vacancy_id)  AS vacancies,
       sum(v.salary_from)            AS total_salary,
       round(1.0 * coalesce(sum(resp.cnt), 0)
             / nullif(count(DISTINCT v.vacancy_id), 0), 1) AS responses_per_vacancy
FROM vacancies v
LEFT JOIN resp ON resp.vacancy_id = v.vacancy_id
WHERE v.closed_at IS NULL
GROUP BY v.professional_role
ORDER BY v.professional_role;

-- Какие два правила из лекции защитили бы от этих ошибок при написании запроса:
-- 1. NULL проверяется только через IS NULL, а не через = (подводный камень №1): закрыло бы
--    ошибку 1, и запрос не вернул бы ноль строк.
-- 2. Объекты считаются по первичному ключу (count(DISTINCT vacancy_id)), а перед агрегацией
--    нужно понимать, чем стала «одна строка» после JOIN; там, где нельзя терять строки
--    основной таблицы, нужен LEFT JOIN. Это закрывает ошибки 2–5 (потерянные вакансии, count(*),
--    размноженная сумма и деление).
