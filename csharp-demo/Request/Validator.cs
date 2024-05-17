
public static class Validator
{

    public static bool Validate<T>(this T entity) where T : class
    {

        Type type = entity.GetType();

        foreach (var item in type.GetProperties())
        {
            if (item.IsDefined(typeof(Request), true))
            {
                foreach (Request attribute in item.GetCustomAttributes(typeof(Request), true))
                {
                    if (attribute == null)
                    {
                        throw new Exception("Validator not instantiate");
                    }
                    if (!attribute.Validate(item.GetValue(entity) ?? ""))
                    {
                        return false;
                    }
                }
            }
        }
        return true;
    }
}