public static class ParameterizeBuilder
{

    public static Dictionary<string, string> Serialize<T>(this T entity) where T : class
    {

        Dictionary<string, string> parameters = new Dictionary<string, string> { };

        Type type = entity.GetType();

        foreach (var property in type.GetProperties())
        {
            if (property.IsDefined(typeof(Request), true))
            {
                foreach (Request attribute in property.GetCustomAttributes(typeof(Request), true))
                {
                    if (attribute == null)
                    {
                        throw new Exception("Paramter not instantiate");
                    }
                    var inner = attribute.Serialize(property.GetValue(entity) ?? "");
                    parameters = merge(parameters, inner);
                }
            }
        }

        return parameters;
    }

    private static Dictionary<string, string> merge(Dictionary<string, string> d1, Dictionary<string, string> d2)
    {
        foreach (var item in d2)
        {
            d1.Add(item.Key, item.Value);
        }
        return d1;
    }
}