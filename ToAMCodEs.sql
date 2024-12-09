-- Requête 1 : Résumé des ventes annuelles et du stock final
WITH yearly_sales AS (
    SELECT 
        p.productCode, -- Code unique du produit
        p.productName, -- Nom du produit
        YEAR(o.orderDate) AS order_year, -- Année de la commande
        SUM(od.quantityOrdered) AS total_quantity_sold -- Total des quantités vendues par année
    FROM 
        products p
    JOIN 
        orderdetails od ON p.productCode = od.productCode -- Association des produits aux détails de commande
    JOIN 
        orders o ON od.orderNumber = o.orderNumber -- Association des commandes
    GROUP BY 
        p.productCode, p.productName, YEAR(o.orderDate) -- Groupement par produit et année
),
stock_summary AS (
    SELECT 
        p.productCode, -- Code du produit
        p.productName, -- Nom du produit
        COALESCE(SUM(ys.total_quantity_sold), 0) AS total_quantity_sold, -- Gérer les produits sans ventes
        p.quantityInStock AS initial_stock, -- Stock initial
        (p.quantityInStock - COALESCE(SUM(ys.total_quantity_sold), 0)) AS final_stock -- Calcul du stock final
    FROM 
        products p
    LEFT JOIN 
        yearly_sales ys ON p.productCode = ys.productCode -- Jointure à gauche pour inclure tous les produits
    GROUP BY 
        p.productCode, p.productName, p.quantityInStock -- Groupement pour chaque produit
)

SELECT 
    ss.productCode, -- Code produit
    ss.productName, -- Nom produit
    ss.initial_stock, -- Stock initial
    ss.total_quantity_sold, -- Total vendu
    ss.final_stock, -- Stock restant
    (SELECT quantityInStock FROM products WHERE productCode = ss.productCode) AS next_year_stock -- Stock pour l'année suivante
FROM 
    stock_summary ss
ORDER BY 
    ss.productCode; -- Tri par code produit

-- Requête 2 : Produits commandés au-delà du stock disponible
SELECT 
    products.productCode, -- Code unique du produit
    orders.orderDate, -- Date de la commande
    products.productName, -- Nom du produit
    SUM(orderdetails.quantityOrdered) AS total_qte_ordered, -- Quantité totale commandée
    products.quantityInStock -- Stock disponible
FROM 
    products
JOIN 
    orderdetails ON products.productCode = orderdetails.productCode -- Jointure pour associer les commandes aux produits
JOIN 
    orders ON orders.orderNumber = orderdetails.orderNumber -- Jointure avec les commandes
GROUP BY 
    products.productCode, products.productName, products.quantityInStock, orders.orderDate -- Groupement par produit et date
HAVING 
    total_qte_ordered > quantityInStock -- Filtrer les cas où la quantité commandée dépasse le stock
ORDER BY 
    total_qte_ordered DESC; -- Tri par quantité commandée décroissante

-- Requête 3 : Classement des villes par ventes par pays (Top 3)
SELECT *
FROM (
    SELECT 
        Customers.country, -- Pays
        Customers.City, -- Ville
        SUM(orderdetails.quantityOrdered * orderdetails.priceEach) AS total_ventes, -- Ventes totales
        RANK() OVER (PARTITION BY Customers.country ORDER BY SUM(orderdetails.quantityOrdered * orderdetails.priceEach) DESC) AS rank_par_ville -- Classement par ventes
    FROM 
        customers
    JOIN 
        orders ON orders.customerNumber = customers.customerNumber -- Association des clients aux commandes
    JOIN 
        orderdetails ON orderdetails.orderNumber = orders.orderNumber -- Association des commandes aux détails
    GROUP BY
        Customers.country, Customers.City -- Groupement par pays et ville
) AS ranked_villes
WHERE rank_par_ville IN (1, 2, 3); -- Sélection des 3 premières villes par pays

-- Requête 4 : Résumé des ventes par pays et année
WITH country_sales_summary AS (
    SELECT 
        c.country, -- Pays
        YEAR(o.orderDate) AS order_year, -- Année de la commande
        SUM(od.quantityOrdered * od.priceEach) AS total_sales -- Total des ventes
    FROM 
        customers c
    JOIN 
        orders o ON c.customerNumber = o.customerNumber -- Association des clients aux commandes
    JOIN 
        orderdetails od ON o.orderNumber = od.orderNumber -- Association des commandes aux détails
    GROUP BY 
        c.country, YEAR(o.orderDate) -- Groupement par pays et année
),
ranked_countries AS (
    SELECT 
        css.country, -- Pays
        SUM(CASE WHEN css.order_year = 2021 THEN css.total_sales ELSE 0 END) AS total_2021, -- Ventes pour 2021
        SUM(CASE WHEN css.order_year = 2022 THEN css.total_sales ELSE 0 END) AS total_2022, -- Ventes pour 2022
        SUM(CASE WHEN css.order_year = 2023 THEN css.total_sales ELSE 0 END) AS total_2023, -- Ventes pour 2023
        SUM(css.total_sales) AS overall_total, -- Total général des ventes
        RANK() OVER (ORDER BY SUM(css.total_sales) DESC) AS rank_par_country -- Classement par pays
    FROM 
        country_sales_summary css
    GROUP BY 
        css.country -- Groupement par pays
)

SELECT 
    country, -- Pays
    total_2021, -- Ventes pour 2021
    total_2022, -- Ventes pour 2022
    total_2023, -- Ventes pour 2023
    overall_total -- Total des ventes
FROM 
    ranked_countries
ORDER BY 
    rank_par_country; -- Tri par classement des pays


-- -- Requête 4 : les délais de livraison 
WITH order_details AS (
    SELECT
        orders.status, -- Statut de la commande (par exemple : Shipped, On Hold, etc.)
        orders.orderNumber, -- Numéro unique de la commande
        orderdetails.productCode, -- Code du produit inclus dans la commande
        orders.requiredDate, -- Date requise pour la livraison
        orders.orderDate, -- Date à laquelle la commande a été passée
        orders.shippedDate, -- Date à laquelle la commande a été expédiée
        orders.comments, -- Commentaires associés à la commande
        DATEDIFF(orders.shippedDate, orders.orderDate) AS delais_de_livraison -- Calcul de la durée en jours entre la commande et l'expédition
    FROM 
        orderdetails 
    LEFT JOIN 
        orders ON orders.orderNumber = orderdetails.orderNumber -- Jointure pour associer les détails de commande aux commandes principales
)

-- Étape 2 : Filtrer les commandes avec des délais de livraison > 6 jours et regrouper par statut
SELECT 
    status, -- Le statut de la commande (par exemple : Shipped, On Hold, etc.)
    COUNT(orderNumber) AS total_orders_delayed -- Nombre total de commandes avec un délai supérieur à 6 jours
FROM 
    order_details -- Utilisation de la CTE définie ci-dessus
WHERE 
    delais_de_livraison > 6 -- Filtrer uniquement les commandes avec des délais supérieurs à 6 jours
GROUP BY 
    status; -- Regrouper les résultats par statut des commandes

