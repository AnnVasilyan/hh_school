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
--    vacancies.salary_from — категория: числовой  тип: INT 
--    vacancies.vacancy_name — категория: строковый  тип: VARCHAR 
--    vacancies.published_at — категория: дата и время  тип: TIMESTAMP
--    employers.is_accredited_it — категория: логический  тип: BOOLEAN
--    responses.created_at — категория: дата и время  тип: TIMESTAMP
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

-- Вывод: самое частое название "Стажёр: аналитик данных", оно встречается 6 раз . Значит,
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
-- открытыми, поэтому актуальность последних нужно проверить. 
-- Во втором запросе без NULLS LAST часть из "топ-10" заняли бы вакансии без зарплаты 
-- и ни одной стажировки.


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
-- неизвестно. Поэтому ошибки нет,  "открытых вакансий нет", поэтому он опаснее ошибки.
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

SELECT count(*) FILTER (WHERE closed_at IS NULL) AS open_cnt,
       count(*) FILTER (WHERE closed_at IS NOT NULL) AS closed_cnt,
       round(100.0 * count(*) FILTER (WHERE closed_at IS NULL) / nullif(count(*), 0), 1) AS open_pct
FROM vacancies;

-- Вывод: в базе 52 вакансии от 12 работодателей, то есть в среднем около 4 вакансий на компанию.
-- Зарплата указана у 44 вакансий из 52, у 8 она не указана.
-- Поэтому среднюю или максимальную зарплату нужно считать без учета вакансий, где зарплата на указана.
-- count(*) считает все строки (52), count(salary_from) только непустые значения (44),
-- а count(DISTINCT ...) только разные значения (5 направлений и 12 работодателей).
-- Сейчас открыто 33 вакансии из 52, это 63,5%, остальные 19 уже закрыты.

-- ЗАДАНИЕ В2
-- Запрос 1: направления — вакансии, работодатели, средняя зарплата
SELECT professional_role,
       count(*) AS vacancies_cnt,
       count(DISTINCT employer_id) AS employers_cnt,
       round(avg(salary_from))  AS avg_salary_from
FROM vacancies
GROUP BY professional_role
ORDER BY vacancies_cnt DESC;

-- Запрос 2: то же, только направления с >= 5 открытыми вакансиями (WHERE + HAVING)
SELECT professional_role,
       count(*) AS open_vacancies_cnt,
       count(DISTINCT employer_id) AS employers_cnt,
       round(avg(salary_from)) AS avg_salary_from
FROM vacancies
WHERE closed_at IS NULL
GROUP BY professional_role
HAVING count(*) >= 5
ORDER BY open_vacancies_cnt DESC;

-- Вывод: больше половины рынка занимают "Аналитик данных" (16 вакансий) и "Разработчик" (15).
-- Нижняя граница зарплаты по открытым вакансиям выше всего у разработчиков и дата-инженеров.
-- По одной этой таблице нельзя делать вывод, так как в ней не учтываются конкуренция 
-- и результаты откликов.

-- По числам во втором запросе разработчики выглядят самым выгодным направлением по деньгам, а
-- аналитики лучшим по числу вакансий, но это средние по вакансиям с указанной зарплатой, а не
-- реальные предложения.
-- ============================================================
-- БЛОК Г. Соединение таблиц
-- ============================================================

-- ЗАДАНИЕ Г1
-- Запрос: топ-5 по salary_from с названием компании и городом (псевдонимы таблиц)
SELECT v.vacancy_name, e.employer_name, a.area_name, v.salary_from
FROM vacancies v
JOIN employers e ON v.employer_id = e.employer_id
JOIN areas a  ON v.area_id = a.area_id
ORDER BY v.salary_from DESC NULLS LAST
LIMIT 5;

-- Вывод: самая высокая нижняя граница у Senior-разработчика в "Северном Коде"
-- (Санкт-Петербург), потом Senior дата-инженер в "УралСофте". 


-- ЗАДАНИЕ Г2
-- Запрос 1: все работодатели, число вакансий и откликов (LEFT JOIN)
SELECT e.employer_name,
       count(DISTINCT v.vacancy_id) AS vacancies_cnt,
       count(r.response_id) AS responses_cnt
FROM employers e
LEFT JOIN vacancies v ON e.employer_id = v.employer_id
LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
GROUP BY e.employer_id, e.employer_name
ORDER BY responses_cnt DESC;

-- Запрос 2: тот же запрос с INNER JOIN
SELECT e.employer_name,
       count(DISTINCT v.vacancy_id) AS vacancies_cnt,
       count(r.response_id) AS responses_cnt
FROM employers e
INNER JOIN vacancies v ON e.employer_id = v.employer_id
INNER JOIN responses r ON v.vacancy_id = r.vacancy_id
GROUP BY e.employer_id, e.employer_name
ORDER BY responses_cnt DESC;

-- Вывод: LEFT JOIN вернул 12 работодателей, INNER JOIN 11: исчез "ГринЭнерго" (1 вакансия, 0 откликов).
-- Это содержательная потеря: именно такую компанию нужно найти, чтобы понять, почему на её
-- вакансию никто не откликнулся. Кроме того, INNER JOIN занизил число вакансий у пяти
-- компаний: у "СибирьТелекома" с 4 до 1, у "Питер Ритейла" с 3 до 1, у DataWave с 7 до 5, у "ТехноБанка"
-- с 9 до 8, у "Северного Кода" с 6 до 5, потому что вакансии без откликов выпали из результата 
-- По откликам на вакансию лучше всех "Казань Диджитал",
-- а у "СибирьТелекома" и "Питер Ритейла" интерес низкий, как и у "ГринЭнерго".

-- ============================================================
-- БЛОК Д. Функции и финальный кейс
-- ============================================================

-- ЗАДАНИЕ Д1
-- Запрос: помесячная динамика откликов и конверсия
-- (месяц как дата, условный агрегат, nullif в знаменателе)
SELECT date_trunc('month', created_at)::date AS month,
       count(*) AS responses_cnt,
       count(*) FILTER (WHERE status = 'invited') AS invited_cnt,
       round(100.0 * count(*) FILTER (WHERE status = 'invited')/ nullif(count(*), 0), 1) AS conversion_pct
FROM responses
GROUP BY 1
ORDER BY 1;

-- Вывод: максимальная конверсия — в июне: 19,5%.
-- Но это один месяц из восьми и один сезон, поэтому планировать на нём набор рано. 
-- Последний месяц, август, неполный: отклики есть только по 15 августа, поэтому его лучше исключить из выводов.


-- ЗАДАНИЕ Д2
-- Запрос: таблица по направлениям (вакансии, отклики, приглашения,
-- откликов на вакансию, конверсия)
-- (LEFT JOIN, чтобы вакансии без откликов попали в знаменатель)
SELECT v.professional_role,
       count(DISTINCT v.vacancy_id) AS vacancies_cnt,
       count(r.response_id) AS responses_cnt,
       count(r.response_id) FILTER (WHERE r.status = 'invited') AS invited_cnt,
       round(1.0 * count(r.response_id)/nullif(count(DISTINCT v.vacancy_id), 0), 1) AS responses_per_vacancy,
       round(100.0 * count(r.response_id) FILTER (WHERE r.status = 'invited')/nullif(count(r.response_id), 0), 1) AS conversion_pct
FROM vacancies v
LEFT JOIN responses r ON v.vacancy_id = r.vacancy_id
GROUP BY v.professional_role
ORDER BY conversion_pct DESC;

-- Письменные ответы:
-- 1. Совпадает ли направление с наибольшим числом вакансий с направлением
--    с наибольшей конверсией?
--    Нет. Больше всего вакансий у "Аналитика данных" (16), но его конверсия 12,1%, 
-- 	  а наибольшая конверсия у "Тестировщика" — 35,9%.
--
-- 2. Какое направление выбрать и почему (опираясь на два столбца):
--    "Разработчик": по числу вакансий (15) и по конверсии (17,3%).
--    Для разработчиков: 24 приглашения и  9,3 отклика на вакансию,
--    то есть конкуренция примерно вдвое ниже, чем у аналитиков.
--    «Тестировщик» лидирует по конверсии, но у него всего 7 вакансий и 39 откликов,
--    поэтому он годится как дополнение, а не как основная ставка.
--
-- 3. Оговорка к выводу:
--    конверсия посчитана от всех откликов, а 276 из 628 откликов ещё в статусах new и
--    viewed и решения по ним нет. Поэтому это доля приглашённых среди всех откликов к моменту
--    выгрузки, а не окончательный шанс получить приглашение, и данные не говорят, подходит ли
--    конкретному кандидату направление.


-- ============================================================
-- БЛОК Е. Со звёздочкой
-- ============================================================

-- ЗАДАНИЕ Е1
-- Исходный запрос (выполнить и посмотреть результат):
SELECT v.professional_role,
count(*) AS vacancies,
sum(v.salary_from) AS total_salary,
count(r.response_id) / count(*) AS responses_per_vacancy
FROM vacancies v
JOIN responses r ON v.vacancy_id = r.vacancy_id
-- WHERE v.closed_at = null
WHERE v.closed_at IS NULL
GROUP BY 1;
--
-- Результат исходного запроса — 0 строк. Если заменить только «= NULL» на IS NULL, остальные
-- ошибки проявятся: у "Аналитика данных" 236 вакансий (реально открыто 11), зарплата
-- 13 870 000 (на самом деле 815 000).
--
-- Ошибки (минимум четыре):
-- 1. WHERE v.closed_at = NULL: запрос возвращает ноль строк. Нужно IS NULL.
-- 2. JOIN responses отбрасывает вакансии без откликов, а они должны попасть в 
--    знаменатель: нужен LEFT JOIN.
-- 3. count(*) считает отклики, а не вакансии. Вакансии считаются через count(DISTINCT v.vacancy_id).
-- 4. sum(v.salary_from) после соединения повторяет зарплату вакансии для каждого её
--    отклика, и сумма завышается. Сумму нужно считать на уровне вакансий до соединения.
-- 5. count(r.response_id) / count(*) —  после INNER JOIN числитель и знаменатель равны. 
--    Нужны nullif в знаменателе и правильный знаменатель (число вакансий, а не строк).
--
-- Исправленный запрос:
WITH resp AS (
    SELECT vacancy_id, count(*) AS cnt
    FROM responses
    GROUP BY vacancy_id
)
SELECT v.professional_role,
       count(DISTINCT v.vacancy_id) AS vacancies,
       sum(v.salary_from) AS total_salary,
       round(1.0 * coalesce(sum(resp.cnt), 0) / nullif(count(DISTINCT v.vacancy_id), 0), 1) AS responses_per_vacancy
FROM vacancies v
LEFT JOIN resp ON resp.vacancy_id = v.vacancy_id
WHERE v.closed_at IS NULL
GROUP BY v.professional_role
ORDER BY v.professional_role;

-- Какие два правила из лекции защитили бы от этих ошибок при написании запроса:
-- 1. NULL проверяется только через IS NULL, а не через = .
-- 2. Объекты считаются по первичному ключу count(DISTINCT vacancy_id), а не count(*).После JOIN
--    одна вакансия повторяется столько раз, сколько у неё откликов, и count(*) считает эти повторы.
--    А если нельзя терять вакансии без откликов, нужен LEFT JOIN, а не INNER JOIN.

