
WITH yearly_sales AS (
    SELECT 
        p.productCode,
        p.productName,
        YEAR(o.orderDate) AS order_year,
        SUM(od.quantityOrdered) AS total_quantity_sold
    FROM 
        products p
    JOIN 
        orderdetails od ON p.productCode = od.productCode
    JOIN 
        orders o ON od.orderNumber = o.orderNumber
    GROUP BY 
        p.productCode, p.productName, YEAR(o.orderDate)
),
stock_summary AS (
    SELECT 
        p.productCode,
        p.productName,
        COALESCE(SUM(ys.total_quantity_sold), 0) AS total_quantity_sold,
        p.quantityInStock AS initial_stock,
        (p.quantityInStock - COALESCE(SUM(ys.total_quantity_sold), 0)) AS final_stock
    FROM 
        products p
    LEFT JOIN 
        yearly_sales ys ON p.productCode = ys.productCode
    GROUP BY 
        p.productCode, p.productName, p.quantityInStock
)

SELECT 
    ss.productCode,
    ss.productName,
    ss.initial_stock,
    ss.total_quantity_sold,
    ss.final_stock,
    (SELECT quantityInStock FROM products WHERE productCode = ss.productCode) AS next_year_stock
FROM 
    stock_summary ss
ORDER BY 
    ss.productCode;
"""),
    nbf.new_markdown_cell("""
### Explication :
1. **Sous-requête yearly_sales** : Calcule les ventes totales par produit et par année.
2. **Sous-requête stock_summary** :
   - Ajoute les informations de stock initial et final pour chaque produit.
   - Utilise COALESCE pour gérer les produits sans ventes.
3. **Requête principale** :
   - Combine les informations pour fournir un résumé complet des stocks et des ventes.
"""),
    nbf.new_markdown_cell("## Requête 2 : Produits commandés au-delà du stock disponible"),
    nbf.new_code_cell("""
SELECT 
    products.productCode,
    orders.orderDate,
    products.productName,
    SUM(orderdetails.quantityOrdered) AS total_qte_ordered,
    products.quantityInStock
FROM 
    products
JOIN 
    orderdetails ON products.productCode = orderdetails.productCode
JOIN 
    orders ON orders.orderNumber = orderdetails.orderNumber
GROUP BY 
    products.productCode, products.productName, products.quantityInStock, orders.orderDate
HAVING 
    total_qte_ordered > quantityInStock
ORDER BY 
    total_qte_ordered DESC;
"""),
    nbf.new_markdown_cell("""
### Explication :
1. **Objectif** : Identifier les produits dont la quantité commandée dépasse le stock disponible.
2. **Utilisation de HAVING** : Filtre les groupes où total_qte_ordered > quantityInStock.
3. **Tri** : Classe les résultats par ordre décroissant des quantités commandées.
"""),
    nbf.new_markdown_cell("## Requête 3 : Classement des villes par ventes par pays (Top 3)"),
    nbf.new_code_cell("""
SELECT *
FROM (
    SELECT 
        Customers.country,
        Customers.City,
        SUM(orderdetails.quantityOrdered * orderdetails.priceEach) AS total_ventes,    
        RANK() OVER (PARTITION BY Customers.country ORDER BY SUM(orderdetails.quantityOrdered * orderdetails.priceEach) DESC) AS rank_par_ville
    FROM 
        customers
    JOIN 
        orders ON orders.customerNumber = customers.customerNumber
    JOIN 
        orderdetails ON orderdetails.orderNumber = orders.orderNumber
    GROUP BY
        Customers.country, Customers.City
) AS ranked_villes
WHERE rank_par_ville IN (1, 2, 3);
"""),
    nbf.new_markdown_cell("""
### Explication :
1. **Sous-requête principale** :
   - Calcule les ventes totales pour chaque ville d'un pays.
   - Utilise RANK() pour classer les villes par ventes dans chaque pays.
2. **Requête externe** :
   - Filtre pour ne conserver que les 3 premières villes de chaque pays.
3. **Utilisation de PARTITION BY** :
   - Permet de créer un classement indépendant pour chaque pays.
"""),
    nbf.new_markdown_cell("## Requête 4 : Résumé des ventes par pays et année"),
    nbf.new_code_cell("""
WITH country_sales_summary AS (
    SELECT 
        c.country,
        YEAR(o.orderDate) AS order_year,
        SUM(od.quantityOrdered * od.priceEach) AS total_sales
    FROM 
        customers c
    JOIN 
        orders o ON c.customerNumber = o.customerNumber
    JOIN 
        orderdetails od ON o.orderNumber = od.orderNumber
    GROUP BY 
        c.country, YEAR(o.orderDate)
),
ranked_countries AS (
    SELECT 
        css.country,
        SUM(CASE WHEN css.order_year = 2021 THEN css.total_sales ELSE 0 END) AS total_2021,
        SUM(CASE WHEN css.order_year = 2022 THEN css.total_sales ELSE 0 END) AS total_2022,
        SUM(CASE WHEN css.order_year = 2023 THEN css.total_sales ELSE 0 END) AS total_2023,
        SUM(css.total_sales) AS overall_total,
        RANK() OVER (ORDER BY SUM(css.total_sales) DESC) AS rank_par_country
    FROM 
        country_sales_summary css
    GROUP BY 
        css.country
)

SELECT 
    country,
    total_2021,
    total_2022,
    total_2023,
    overall_total
FROM 
    ranked_countries
ORDER BY 
    rank_par_country;
"""),
    nbf.new_markdown_cell("""
### Explication :
1. **Sous-requête country_sales_summary** :
   - Calcule les ventes totales pour chaque pays et chaque année.
2. **Sous-requête ranked_countries** :
   - Ajoute des colonnes spécifiques pour les ventes annuelles.
   - Classe les pays par ventes totales.
3. **Requête principale** :
   - Sélectionne les informations pertinentes et les trie par classement.
"""),
]

 